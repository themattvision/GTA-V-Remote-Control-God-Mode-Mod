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
        StatusChanged?.Invoke($"In ascolto, porta {port}");
        _ = AcceptLoopAsync(_lifetime.Token);
        _ = StateLoopAsync(_lifetime.Token);
    }

    public async Task ResolvePairingAsync(bool approved)
    {
        await _pairingGate.WaitAsync().ConfigureAwait(false);
        try
        {
            var pending = _pendingPairing ?? throw new InvalidOperationException("Non c'è un pairing da approvare.");
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
                StatusChanged?.Invoke("Pairing approvato, attendo l'autenticazione cifrata");
            }
            else
            {
                await pending.Session.SendPairingApprovalAsync(approval, _lifetime?.Token ?? default).ConfigureAwait(false);
                StatusChanged?.Invoke("Pairing rifiutato");
            }
            ClearPendingPairing();
        }
        finally
        {
            _pairingGate.Release();
        }
    }

    internal void OnPairingNeeded() => StatusChanged?.Invoke("iPhone rilevato, pairing necessario");

    internal void OnAuthenticating(Guid clientID)
    {
        _rateLimiters[clientID] = new RateLimiter();
        StatusChanged?.Invoke("iPhone noto, attendo l'autenticazione cifrata");
    }

    internal async Task RequestPairingAsync(
        BridgeClientSession session,
        PairingRequest request,
        CancellationToken cancellationToken)
    {
        await _pairingGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_pendingPairing is not null) throw new InvalidOperationException("È già presente una richiesta di pairing.");
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
                StatusChanged?.Invoke("Confronta il codice e approva il pairing");
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
        StatusChanged?.Invoke($"iPhone connesso, {clientID.ToString()[..8]}");
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
                Diagnostic?.Invoke("Comando eseguito");
            }
            catch (Exception error) when (error is not OperationCanceledException)
            {
                accepted = false;
                Diagnostic?.Invoke(error.Message);
            }
        }
        else
        {
            Diagnostic?.Invoke("Troppi comandi, richiesta rifiutata");
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
            StatusChanged?.Invoke($"Errore listener: {error.Message}");
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
            Diagnostic?.Invoke($"Connessione rifiutata: {error.Message}");
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
                StatusChanged?.Invoke("In ascolto sulla rete locale");
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
                            Diagnostic?.Invoke($"Stato non inviato: {error.Message}");
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
