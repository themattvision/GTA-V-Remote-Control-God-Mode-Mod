using System.Net.Sockets;
using System.Text.Json;
using GTAControlCore.Windows;
using GTABridge.Windows.Storage;

namespace GTABridge.Windows.Networking;

internal sealed class BridgeClientSession : IAsyncDisposable
{
    private readonly TcpClient _client;
    private readonly NetworkStream _stream;
    private readonly Guid _bridgeID;
    private readonly ProtectedSessionStore _sessionStore;
    private readonly BridgeServer _server;
    private readonly FrameDecoder _decoder = new();
    private readonly SemaphoreSlim _sendGate = new(1, 1);
    private readonly object _channelGate = new();
    private SecureChannel? _secureChannel;
    private Guid? _presentedClientID;
    private bool _authenticated;
    private int _disposed;

    public BridgeClientSession(
        TcpClient client,
        Guid bridgeID,
        ProtectedSessionStore sessionStore,
        BridgeServer server)
    {
        _client = client;
        _client.NoDelay = true;
        _stream = client.GetStream();
        _bridgeID = bridgeID;
        _sessionStore = sessionStore;
        _server = server;
    }

    public Guid ID { get; } = Guid.NewGuid();
    public Guid? ClientID { get; private set; }
    public bool IsAuthenticated => _authenticated;

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        var buffer = new byte[ProtocolConstants.MaximumFrameBytes + 4];
        while (!cancellationToken.IsCancellationRequested)
        {
            var count = await _stream.ReadAsync(buffer, cancellationToken).ConfigureAwait(false);
            if (count == 0) return;
            foreach (var frame in _decoder.Append(buffer.AsSpan(0, count)))
                await HandleFrameAsync(frame, cancellationToken).ConfigureAwait(false);
        }
    }

    public void ActivateSecureChannel(byte[] sessionKey, Guid clientID)
    {
        ClientID = clientID;
        lock (_channelGate)
        {
            _secureChannel?.Dispose();
            _secureChannel = new SecureChannel(sessionKey);
        }
    }

    public Task SendPairingChallengeAsync(PairingChallenge challenge, CancellationToken cancellationToken) =>
        SendClearAsync(WireMessage.PairingChallenge(challenge), cancellationToken);

    public Task SendPairingApprovalAsync(PairingApproval approval, CancellationToken cancellationToken) =>
        SendClearAsync(WireMessage.PairingApproval(approval), cancellationToken);

    public Task SendAcknowledgementAsync(AcknowledgementMessage acknowledgement, CancellationToken cancellationToken) =>
        SendSecureAsync(WireMessage.Acknowledgement(acknowledgement), cancellationToken);

    public async Task SendTrainerStateAsync(TrainerStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        if (_authenticated)
            await SendSecureAsync(WireMessage.TrainerState(snapshot), cancellationToken).ConfigureAwait(false);
    }

    private async Task HandleFrameAsync(byte[] frame, CancellationToken cancellationToken)
    {
        if (ClientID is null)
        {
            await HandleClearAsync(ProtocolJson.Decode(frame), cancellationToken).ConfigureAwait(false);
            return;
        }

        if (!_authenticated && TryDecodePairingRequest(frame, out var request) && request.ClientID == _presentedClientID)
        {
            _sessionStore.Remove(ClientID.Value);
            ClientID = null;
            lock (_channelGate)
            {
                _secureChannel?.Dispose();
                _secureChannel = null;
            }
            await HandleClearAsync(new WireMessage("pairingRequest", request), cancellationToken).ConfigureAwait(false);
            return;
        }

        WireMessage message;
        lock (_channelGate)
        {
            if (_secureChannel is null) throw new InvalidDataException(LocalizedText.Choose(
                "Pairing richiesto.",
                "Pairing required."));
            message = _secureChannel.Open(frame);
        }
        await HandleSecureAsync(message, cancellationToken).ConfigureAwait(false);
    }

    private async Task HandleClearAsync(WireMessage message, CancellationToken cancellationToken)
    {
        switch (message.Payload)
        {
            case HelloMessage hello:
                if (hello.Role != PeerRole.Controller) throw new InvalidDataException(LocalizedText.Choose(
                    "Il peer non è un controller.",
                    "The peer is not a controller."));
                if (_presentedClientID is not null && _presentedClientID != hello.PeerID)
                    throw new InvalidDataException(LocalizedText.Choose(
                        "L'identità del client è cambiata durante la connessione.",
                        "The client identity changed during the connection."));
                _presentedClientID = hello.PeerID;
                await SendClearAsync(WireMessage.Hello(_bridgeID, PeerRole.Bridge), cancellationToken).ConfigureAwait(false);
                var storedKey = _sessionStore.Load(hello.PeerID);
                if (storedKey is not null)
                {
                    try
                    {
                        ActivateSecureChannel(storedKey, hello.PeerID);
                    }
                    finally
                    {
                        System.Security.Cryptography.CryptographicOperations.ZeroMemory(storedKey);
                    }
                    _server.OnAuthenticating(hello.PeerID);
                }
                else
                {
                    _server.OnPairingNeeded();
                }
                break;

            case PairingRequest pairingRequest when ClientID is null && pairingRequest.ClientID == _presentedClientID:
                await _server.RequestPairingAsync(this, pairingRequest, cancellationToken).ConfigureAwait(false);
                break;

            default:
                throw new InvalidDataException(_presentedClientID is null
                    ? LocalizedText.Choose("Il client deve inviare hello per primo.", "The client must send hello first.")
                    : LocalizedText.Choose("Messaggio in chiaro non consentito.", "Clear-text message not allowed."));
        }
    }

    private async Task HandleSecureAsync(WireMessage message, CancellationToken cancellationToken)
    {
        switch (message.Payload)
        {
            case HeartbeatMessage:
                await SendHeartbeatAsync(cancellationToken).ConfigureAwait(false);
                if (!_authenticated && ClientID is { } clientID)
                {
                    _authenticated = true;
                    await _server.OnAuthenticatedAsync(this, clientID, cancellationToken).ConfigureAwait(false);
                }
                break;

            case CommandMessage command:
                RequireAuthenticated(command.Envelope.ClientID);
                await _server.HandleCommandAsync(this, command, cancellationToken).ConfigureAwait(false);
                break;

            case GodModeCommandMessage command:
                RequireAuthenticated(command.ClientID);
                await _server.HandleGodModeAsync(this, command, cancellationToken).ConfigureAwait(false);
                break;

            case WreckPreservationCommandMessage command:
                RequireAuthenticated(command.ClientID);
                await _server.HandleWreckPreservationAsync(this, command, cancellationToken).ConfigureAwait(false);
                break;

            default:
                throw new InvalidDataException(LocalizedText.Choose(
                    "Messaggio cifrato non consentito.",
                    "Encrypted message not allowed."));
        }
    }

    private void RequireAuthenticated(Guid clientID)
    {
        if (!_authenticated) throw new InvalidDataException(LocalizedText.Choose(
            "Heartbeat cifrato richiesto prima dei comandi.",
            "An encrypted heartbeat is required before commands."));
        if (clientID != ClientID) throw new InvalidDataException(LocalizedText.Choose(
            "Identità client non valida.",
            "Invalid client identity."));
    }

    private Task SendHeartbeatAsync(CancellationToken cancellationToken)
    {
        EncryptedPacket packet;
        lock (_channelGate)
        {
            if (_secureChannel is null) throw new InvalidDataException(LocalizedText.Choose(
                "Canale cifrato assente.",
                "Encrypted channel is unavailable."));
            packet = _secureChannel.Seal(WireMessage.Heartbeat(_secureChannel.NextSendingSequence));
        }
        var payload = JsonSerializer.SerializeToUtf8Bytes(packet, ProtocolJson.Options);
        return SendFrameAsync(FrameCodec.Encode(payload), cancellationToken);
    }

    private Task SendClearAsync(WireMessage message, CancellationToken cancellationToken) =>
        SendFrameAsync(FrameCodec.Encode(ProtocolJson.Encode(message)), cancellationToken);

    private Task SendSecureAsync(WireMessage message, CancellationToken cancellationToken)
    {
        EncryptedPacket packet;
        lock (_channelGate)
        {
            if (_secureChannel is null) throw new InvalidDataException(LocalizedText.Choose(
                "Canale cifrato assente.",
                "Encrypted channel is unavailable."));
            packet = _secureChannel.Seal(message);
        }
        var payload = JsonSerializer.SerializeToUtf8Bytes(packet, ProtocolJson.Options);
        return SendFrameAsync(FrameCodec.Encode(payload), cancellationToken);
    }

    private async Task SendFrameAsync(byte[] frame, CancellationToken cancellationToken)
    {
        await _sendGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await _stream.WriteAsync(frame, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _sendGate.Release();
        }
    }

    private static bool TryDecodePairingRequest(byte[] frame, out PairingRequest request)
    {
        try
        {
            var message = ProtocolJson.Decode(frame);
            if (message.Payload is PairingRequest value)
            {
                request = value;
                return true;
            }
        }
        catch (Exception error) when (error is JsonException or InvalidDataException)
        {
        }
        request = null!;
        return false;
    }

    public async ValueTask DisposeAsync()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0) return;
        lock (_channelGate)
        {
            _secureChannel?.Dispose();
            _secureChannel = null;
        }
        _client.Dispose();
        _sendGate.Dispose();
        await ValueTask.CompletedTask;
    }
}
