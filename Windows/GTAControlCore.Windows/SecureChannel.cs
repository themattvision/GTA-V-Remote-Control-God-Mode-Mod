using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace GTAControlCore.Windows;

public sealed class SecureChannel : IDisposable
{
    private readonly byte[] _sessionKey;
    private ulong _nextSendingSequence = 1;
    private ulong? _highestReceivedSequence;

    public SecureChannel(ReadOnlySpan<byte> sessionKey)
    {
        if (sessionKey.Length != 32) throw new CryptographicException("Chiave di sessione non valida.");
        _sessionKey = sessionKey.ToArray();
    }

    public ulong NextSendingSequence => _nextSendingSequence;

    public EncryptedPacket Seal(WireMessage message)
    {
        if (_nextSendingSequence == 0) throw new CryptographicException("Sequenza esaurita.");
        var sequence = _nextSendingSequence;
        var plaintext = ProtocolJson.Encode(message);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];
        using var algorithm = new ChaCha20Poly1305(_sessionKey);
        algorithm.Encrypt(nonce, plaintext, ciphertext, tag, AuthenticatedData(sequence));
        var combined = new byte[nonce.Length + ciphertext.Length + tag.Length];
        nonce.CopyTo(combined, 0);
        ciphertext.CopyTo(combined, nonce.Length);
        tag.CopyTo(combined, nonce.Length + ciphertext.Length);
        _nextSendingSequence = sequence == ulong.MaxValue ? 0 : sequence + 1;
        return new EncryptedPacket(ProtocolConstants.Version, sequence, combined);
    }

    public WireMessage Open(ReadOnlySpan<byte> payload)
    {
        var packet = JsonSerializer.Deserialize<EncryptedPacket>(payload, ProtocolJson.Options)
            ?? throw new InvalidDataException("Pacchetto cifrato non valido.");
        return Open(packet);
    }

    public WireMessage Open(EncryptedPacket packet)
    {
        if (packet.ProtocolVersion != ProtocolConstants.Version)
            throw new InvalidDataException("Versione cifratura non supportata.");
        if (packet.Sequence == 0) throw new InvalidDataException("Sequenza non valida.");
        if (_highestReceivedSequence is { } highest && packet.Sequence <= highest)
            throw new InvalidDataException("Replay rilevato.");
        if (packet.CombinedCiphertext.Length < 28)
            throw new CryptographicException("Pacchetto cifrato troppo corto.");

        var nonce = packet.CombinedCiphertext.AsSpan(0, 12);
        var ciphertext = packet.CombinedCiphertext.AsSpan(12, packet.CombinedCiphertext.Length - 28);
        var tag = packet.CombinedCiphertext.AsSpan(packet.CombinedCiphertext.Length - 16);
        var plaintext = new byte[ciphertext.Length];
        using var algorithm = new ChaCha20Poly1305(_sessionKey);
        algorithm.Decrypt(nonce, ciphertext, tag, plaintext, AuthenticatedData(packet.Sequence));
        var message = ProtocolJson.Decode(plaintext);
        var embedded = EmbeddedSequence(message);
        if (embedded is { } value && value != packet.Sequence)
            throw new InvalidDataException("Sequenza interna non coerente.");
        _highestReceivedSequence = packet.Sequence;
        return message;
    }

    private static byte[] AuthenticatedData(ulong sequence)
    {
        var prefix = Encoding.UTF8.GetBytes("GTAControl-Packet-v1");
        var data = new byte[prefix.Length + 10];
        prefix.CopyTo(data, 0);
        BinaryPrimitives.WriteUInt16BigEndian(data.AsSpan(prefix.Length), ProtocolConstants.Version);
        BinaryPrimitives.WriteUInt64BigEndian(data.AsSpan(prefix.Length + 2), sequence);
        return data;
    }

    private static ulong? EmbeddedSequence(WireMessage message) => message.Payload switch
    {
        CommandMessage command => command.Envelope.Sequence,
        HeartbeatMessage heartbeat => heartbeat.Sequence,
        _ => null,
    };

    public void Dispose() => CryptographicOperations.ZeroMemory(_sessionKey);
}
