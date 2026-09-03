using System.Text.Json;
using System.Text.Json.Serialization;

namespace GTAControlCore.Windows;

public static class ProtocolConstants
{
    public const ushort Version = 3;
    public const string BonjourType = "_gtactrl._tcp";
    public const int MaximumFrameBytes = 16_384;
    public const int MaximumCommandsPerSecond = 20;
}

public enum PeerRole { Controller, Bridge }

public enum TrainerCommand
{
    ToggleTrainer,
    MoveUp,
    MoveDown,
    MoveLeft,
    MoveRight,
    Select,
    Back,
    NumpadBack,
    VehicleBoostUp,
    VehicleBoostDown,
    VehicleRockets,
}

public enum AcknowledgementStatus { Accepted, Rejected }

public enum ProtocolErrorCode
{
    UnsupportedVersion,
    MalformedMessage,
    PairingDenied,
    AuthenticationFailed,
    ReplayDetected,
    RateLimited,
    InvalidSequence,
    CommandRejected,
}

public sealed record HelloMessage(ushort ProtocolVersion, Guid PeerID, PeerRole Role);
public sealed record PairingRequest(ushort ProtocolVersion, Guid ClientID, byte[] ClientPublicKey);
public sealed record PairingChallenge(ushort ProtocolVersion, Guid BridgeID, byte[] BridgePublicKey, uint Fingerprint);
public sealed record PairingApproval(ushort ProtocolVersion, Guid ClientID, Guid BridgeID, bool Approved);
public sealed record CommandEnvelope(ushort ProtocolVersion, Guid ClientID, Guid RequestID, ulong Sequence, TrainerCommand Command);
public sealed record CommandMessage(CommandEnvelope Envelope);
public sealed record GodModeCommandMessage(ushort ProtocolVersion, Guid ClientID, Guid RequestID, ulong Sequence, bool Enabled);
public sealed record WreckPreservationCommandMessage(ushort ProtocolVersion, Guid ClientID, Guid RequestID, ulong Sequence, bool Enabled);
public sealed record AcknowledgementMessage(ushort ProtocolVersion, Guid RequestID, ulong Sequence, AcknowledgementStatus Status);
public sealed record ProtocolErrorMessage(ushort ProtocolVersion, Guid? RequestID, ProtocolErrorCode Code);
public sealed record HeartbeatMessage(ushort ProtocolVersion, ulong Sequence);
public sealed record TrainerStateSnapshot(bool IsDirectControlReady, bool? GodModeEnabled, bool? WreckPreservationEnabled, int? PreservedWreckCount);
public sealed record TrainerStateMessage(ushort ProtocolVersion, TrainerStateSnapshot Snapshot);
public sealed record EncryptedPacket(ushort ProtocolVersion, ulong Sequence, byte[] CombinedCiphertext);

public sealed record WireMessage(string Kind, object Payload)
{
    public ushort ProtocolVersion => Payload switch
    {
        HelloMessage value => value.ProtocolVersion,
        PairingRequest value => value.ProtocolVersion,
        PairingChallenge value => value.ProtocolVersion,
        PairingApproval value => value.ProtocolVersion,
        CommandMessage value => value.Envelope.ProtocolVersion,
        GodModeCommandMessage value => value.ProtocolVersion,
        WreckPreservationCommandMessage value => value.ProtocolVersion,
        AcknowledgementMessage value => value.ProtocolVersion,
        ProtocolErrorMessage value => value.ProtocolVersion,
        HeartbeatMessage value => value.ProtocolVersion,
        TrainerStateMessage value => value.ProtocolVersion,
        _ => throw new InvalidDataException("Tipo di messaggio non supportato."),
    };

    public static WireMessage Hello(Guid peerID, PeerRole role) =>
        new("hello", new HelloMessage(ProtocolConstants.Version, peerID, role));
    public static WireMessage PairingChallenge(PairingChallenge value) => new("pairingChallenge", value);
    public static WireMessage PairingApproval(PairingApproval value) => new("pairingApproval", value);
    public static WireMessage Acknowledgement(AcknowledgementMessage value) => new("acknowledgement", value);
    public static WireMessage Error(ProtocolErrorMessage value) => new("error", value);
    public static WireMessage Heartbeat(ulong sequence) =>
        new("heartbeat", new HeartbeatMessage(ProtocolConstants.Version, sequence));
    public static WireMessage TrainerState(TrainerStateSnapshot snapshot) =>
        new("trainerState", new TrainerStateMessage(ProtocolConstants.Version, snapshot));
}

public static class ProtocolJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DictionaryKeyPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
        WriteIndented = false,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public static byte[] Encode(WireMessage message)
    {
        var payload = JsonSerializer.SerializeToUtf8Bytes(message, Options);
        ValidatePayload(payload);
        return payload;
    }

    public static WireMessage Decode(ReadOnlySpan<byte> payload)
    {
        ValidatePayload(payload);
        using var document = JsonDocument.Parse(payload.ToArray());
        var root = document.RootElement;
        var kind = root.GetProperty("kind").GetString() ?? throw new InvalidDataException("kind assente.");
        var value = root.GetProperty("payload");
        object decoded = kind switch
        {
            "hello" => Deserialize<HelloMessage>(value),
            "pairingRequest" => Deserialize<PairingRequest>(value),
            "pairingChallenge" => Deserialize<PairingChallenge>(value),
            "pairingApproval" => Deserialize<PairingApproval>(value),
            "command" => Deserialize<CommandMessage>(value),
            "godModeCommand" => Deserialize<GodModeCommandMessage>(value),
            "wreckPreservationCommand" => Deserialize<WreckPreservationCommandMessage>(value),
            "acknowledgement" => Deserialize<AcknowledgementMessage>(value),
            "error" => Deserialize<ProtocolErrorMessage>(value),
            "heartbeat" => Deserialize<HeartbeatMessage>(value),
            "trainerState" => Deserialize<TrainerStateMessage>(value),
            _ => throw new InvalidDataException("kind sconosciuto."),
        };
        var message = new WireMessage(kind, decoded);
        if (message.ProtocolVersion != ProtocolConstants.Version)
            throw new InvalidDataException($"Versione protocollo {message.ProtocolVersion} non supportata.");
        return message;
    }

    private static T Deserialize<T>(JsonElement value) =>
        value.Deserialize<T>(Options) ?? throw new InvalidDataException("payload non valido.");

    private static void ValidatePayload(ReadOnlySpan<byte> payload)
    {
        if (payload.IsEmpty) throw new InvalidDataException("Frame vuoto.");
        if (payload.Length > ProtocolConstants.MaximumFrameBytes)
            throw new InvalidDataException("Frame troppo grande.");
    }
}
