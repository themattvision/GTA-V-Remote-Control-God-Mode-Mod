using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using GTAControlCore.Windows;
using GTABridge.Windows.Game;
using GTABridge.Windows.Storage;

namespace GTABridge.Windows.Networking;

internal sealed class BridgeServer : IAsyncDisposable
{
    private sealed record PendingPairing(
        Guid ClientID,
        PairingKeyPair KeyPair,
        byte[] SessionKey,
        uint Fingerprint,
        BridgeClientSession Session);

    private readonly Guid _bridgeID;
    private readonly ProtectedSessionStore _sessionStore;
    private readonly TrainerInputInjector _input;
    private readonly GameModStateProvider _mod;
    private readonly BonjourAdvertiser _advertiser = new();
    private readonly ConcurrentDictionary<Guid, BridgeClientSession> _sessions = new();
    private readonly ConcurrentDictionary<Guid, RateLimiter> _rateLimiters = new();
    private readonly SemaphoreSlim _pairingGate = new(1, 1);
    private CancellationTokenSource? _lifetime;
    private TcpListener? _listener;
    private PendingPairing? _pendingPairing;
    private TrainerStateSnapshot _lastState = new(false, null, null, null);

    public BridgeServer(Guid bridgeID, ProtectedSessionStore sessionStore, TrainerInputInjector input, GameModStateProvider mod)
    {
        _bridgeID = bridgeID;
        _sessionStore = sessionStore;
        _input = input;
        _mod = mod;
    }

    public event Action<string>? StatusChanged;
    public event Action<Guid, uint>? PairingRequested;
    public event Action? PairingCleared;
    public event Action<string>? Diagnostic;

    public void Start()
    {
        if (_lifetime is not null) return;
        _lifetime = new CancellationTokenSource();
        _listener = new TcpListener(IPAddress.IPv6Any, 0);
        _listener.Server.DualMode = true;
        _listener.Start();
        var port = ((IPEndPoint)_listener.LocalEndpoint).Port;
        _advertiser.Start(port);
        StatusChanged?.Invoke($"{LocalizedText.Choose("In ascolto, porta", "Listening on port")} {port}");
        _ = AcceptLoopAsync(_lifetime.Token);
        _ = StateLoopAsync(_lifetime.Token);
    }

    public async Task ResolvePairingAsync(bool approved)
    {
        await _pairingGate.WaitAsync().ConfigureAwait(false);
        try
        {
            var pending = _pendingPairing ?? throw new InvalidOperationException(LocalizedText.Choose(
                "Non c'è un pairing da approvare.",
                "There is no pairing request to approve."));
            var approval = new PairingApproval(ProtocolConstants.Version, pending.ClientID, _bridgeID, approved);
            if (approved)
            {
                _sessionStore.Save(pending.ClientID, pending.SessionKey);
                pending.Session.ActivateSecureChannel(pending.SessionKey, pending.ClientID);
                try
                {
                    await pending.Session.SendPairingApprovalAsync(approval, _lifetime?.Token ?? default).ConfigureAwait(false);
                }
                catch
                {
                    _sessionStore.Remove(pending.ClientID);
                    throw;
                }
                _rateLimiters[pending.ClientID] = new RateLimiter();
                StatusChanged?.Invoke(LocalizedText.Choose(
                    "Pairing approvato, attendo l'autenticazione cifrata",
                    "Pairing approved, waiting for encrypted authentication"));
            }
            else
            {
                await pending.Session.SendPairingApprovalAsync(approval, _lifetime?.Token ?? default).ConfigureAwait(false);
                StatusChanged?.Invoke(LocalizedText.Choose("Pairing rifiutato", "Pairing rejected"));
            }
            ClearPendingPairing();
        }
        finally
        {
            _pairingGate.Release();
        }
    }

    internal void OnPairingNeeded() => StatusChanged?.Invoke(LocalizedText.Choose(
        "iPhone rilevato, pairing necessario",
        "iPhone detected, pairing required"));

    internal void OnAuthenticating(Guid clientID)
    {
        _rateLimiters[clientID] = new RateLimiter();
        StatusChanged?.Invoke(LocalizedText.Choose(
            "iPhone noto, attendo l'autenticazione cifrata",
            "Known iPhone, waiting for encrypted authentication"));
    }

    internal async Task RequestPairingAsync(
        BridgeClientSession session,
        PairingRequest request,
        CancellationToken cancellationToken)
    {
        await _pairingGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_pendingPairing is not null) throw new InvalidOperationException(LocalizedText.Choose(
                "È già presente una richiesta di pairing.",
                "A pairing request is already pending."));
            var keyPair = new PairingKeyPair();
            PendingPairing? pending = null;
            try
            {
                var fingerprint = keyPair.Fingerprint(request.ClientPublicKey);
                var sessionKey = keyPair.DeriveSessionKey(request.ClientPublicKey);
                var challenge = new PairingChallenge(
                    ProtocolConstants.Version,
                    _bridgeID,
                    keyPair.PublicKey,
                    fingerprint);
                pending = new PendingPairing(request.ClientID, keyPair, sessionKey, fingerprint, session);
                _pendingPairing = pending;
                await session.SendPairingChallengeAsync(challenge, cancellationToken).ConfigureAwait(false);
                PairingRequested?.Invoke(request.ClientID, fingerprint);
                StatusChanged?.Invoke(LocalizedText.Choose(
                    "Confronta il codice e approva il pairing",
                    "Compare the code and approve pairing"));
            }
            catch
            {
                if (pending is not null && ReferenceEquals(_pendingPairing, pending))
                    ClearPendingPairing();
                else
                    keyPair.Dispose();
                throw;
            }
        }
        finally
        {
            _pairingGate.Release();
        }
    }

    internal async Task OnAuthenticatedAsync(
        BridgeClientSession session,
        Guid clientID,
        CancellationToken cancellationToken)
    {
        StatusChanged?.Invoke($"{LocalizedText.Choose("iPhone connesso", "iPhone connected")}, {clientID.ToString()[..8]}");
        await session.SendTrainerStateAsync(_lastState, cancellationToken).ConfigureAwait(false);
    }

    internal Task HandleCommandAsync(
        BridgeClientSession session,
        CommandMessage command,
        CancellationToken cancellationToken) =>
        ExecuteAsync(
            session,
            command.Envelope.ClientID,
            command.Envelope.RequestID,
            command.Envelope.Sequence,
            () => _input.InjectAsync(command.Envelope.Command, cancellationToken),
            cancellationToken);

    internal Task HandleGodModeAsync(
        BridgeClientSession session,
        GodModeCommandMessage command,
        CancellationToken cancellationToken) =>
        ExecuteAsync(session, command.ClientID, command.RequestID, command.Sequence,
            () => { _mod.SetGodMode(command.Enabled); return Task.CompletedTask; }, cancellationToken);

    internal Task HandleWreckPreservationAsync(
        BridgeClientSession session,
        WreckPreservationCommandMessage command,
        CancellationToken cancellationToken) =>
        ExecuteAsync(session, command.ClientID, command.RequestID, command.Sequence,
            () => { _mod.SetWreckPreservation(command.Enabled); return Task.CompletedTask; }, cancellationToken);

    private async Task ExecuteAsync(
        BridgeClientSession session,
        Guid clientID,
        Guid requestID,
        ulong sequence,
        Func<Task> action,
        CancellationToken cancellationToken)
    {
        var limiter = _rateLimiters.GetOrAdd(clientID, _ => new RateLimiter());
        var accepted = limiter.Allow();
        if (accepted)
        {
            try
            {
                await action().ConfigureAwait(false);
                Diagnostic?.Invoke(LocalizedText.Choose("Comando eseguito", "Command executed"));
            }
            catch (Exception error) when (error is not OperationCanceledException)
            {
                accepted = false;
                Diagnostic?.Invoke(error.Message);
            }
        }
        else
        {
            Diagnostic?.Invoke(LocalizedText.Choose(
                "Troppi comandi, richiesta rifiutata",
                "Too many commands, request rejected"));
        }

        await session.SendAcknowledgementAsync(
            new AcknowledgementMessage(
                ProtocolConstants.Version,
                requestID,
                sequence,
                accepted ? AcknowledgementStatus.Accepted : AcknowledgementStatus.Rejected),
            cancellationToken).ConfigureAwait(false);
    }

    private async Task AcceptLoopAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested && _listener is not null)
            {
                var client = await _listener.AcceptTcpClientAsync(cancellationToken).ConfigureAwait(false);
                var session = new BridgeClientSession(client, _bridgeID, _sessionStore, this);
                _sessions[session.ID] = session;
                _ = RunSessionAsync(session, cancellationToken);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception error)
        {
            StatusChanged?.Invoke($"{LocalizedText.Choose("Errore listener", "Listener error")}: {error.Message}");
        }
    }

    private async Task RunSessionAsync(BridgeClientSession session, CancellationToken cancellationToken)
    {
        try
        {
            await session.RunAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception error)
        {
            Diagnostic?.Invoke($"{LocalizedText.Choose("Connessione rifiutata", "Connection rejected")}: {error.Message}");
        }
        finally
        {
            _sessions.TryRemove(session.ID, out _);
            await _pairingGate.WaitAsync().ConfigureAwait(false);
            try
            {
                if (_pendingPairing?.Session == session) ClearPendingPairing();
            }
            finally
            {
                _pairingGate.Release();
            }
            await session.DisposeAsync().ConfigureAwait(false);
            if (!_sessions.Values.Any(value => value.IsAuthenticated))
                StatusChanged?.Invoke(LocalizedText.Choose("In ascolto sulla rete locale", "Listening on the local network"));
        }
    }

    private async Task StateLoopAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var snapshot = _mod.CurrentState();
                if (snapshot != _lastState)
                {
                    _lastState = snapshot;
                    foreach (var session in _sessions.Values)
                    {
                        try { await session.SendTrainerStateAsync(snapshot, cancellationToken).ConfigureAwait(false); }
                        catch (Exception error) when (error is not OperationCanceledException)
                        {
                            Diagnostic?.Invoke($"{LocalizedText.Choose("Stato non inviato", "State not sent")}: {error.Message}");
                        }
                    }
                }
                await Task.Delay(250, cancellationToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
    }

    private void ClearPendingPairing()
    {
        var pending = Interlocked.Exchange(ref _pendingPairing, null);
        if (pending is not null)
        {
            CryptographicOperations.ZeroMemory(pending.SessionKey);
            pending.KeyPair.Dispose();
        }
        PairingCleared?.Invoke();
    }

    public async ValueTask DisposeAsync()
    {
        var lifetime = Interlocked.Exchange(ref _lifetime, null);
        if (lifetime is null) return;
        lifetime.Cancel();
        _listener?.Stop();
        _listener = null;
        _advertiser.Dispose();
        await _pairingGate.WaitAsync().ConfigureAwait(false);
        try
        {
            ClearPendingPairing();
        }
        finally
        {
            _pairingGate.Release();
        }
        foreach (var session in _sessions.Values)
            await session.DisposeAsync().ConfigureAwait(false);
        _sessions.Clear();
        lifetime.Dispose();
    }
}
