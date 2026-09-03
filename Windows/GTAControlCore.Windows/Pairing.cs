using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using NSec.Cryptography;

namespace GTAControlCore.Windows;

public sealed class PairingKeyPair : IDisposable
{
    private static readonly KeyAgreementAlgorithm Algorithm = KeyAgreementAlgorithm.X25519;
    private readonly Key _privateKey;

    public PairingKeyPair()
    {
        _privateKey = new Key(Algorithm, new KeyCreationParameters
        {
            ExportPolicy = KeyExportPolicies.None,
        });
        PublicKey = _privateKey.PublicKey.Export(KeyBlobFormat.RawPublicKey);
    }

    internal PairingKeyPair(ReadOnlySpan<byte> rawPrivateKey)
    {
        if (rawPrivateKey.Length != 32) throw new CryptographicException("Chiave privata X25519 non valida.");
        _privateKey = Key.Import(
            Algorithm,
            rawPrivateKey,
            KeyBlobFormat.RawPrivateKey,
            new KeyCreationParameters { ExportPolicy = KeyExportPolicies.None });
        PublicKey = _privateKey.PublicKey.Export(KeyBlobFormat.RawPublicKey);
    }

    public byte[] PublicKey { get; }

    public uint Fingerprint(ReadOnlySpan<byte> remotePublicKey)
    {
        ValidatePublicKey(remotePublicKey);
        var ordered = OrderKeys(PublicKey, remotePublicKey.ToArray());
        var prefix = Encoding.UTF8.GetBytes("GTAControl-Pairing-Fingerprint-v1");
        var material = new byte[prefix.Length + 64];
        prefix.CopyTo(material, 0);
        ordered.First.CopyTo(material, prefix.Length);
        ordered.Second.CopyTo(material, prefix.Length + 32);
        var digest = SHA256.HashData(material);
        return (uint)(BinaryPrimitives.ReadUInt64BigEndian(digest) % 1_000_000);
    }

    public byte[] DeriveSessionKey(ReadOnlySpan<byte> remotePublicKey)
    {
        ValidatePublicKey(remotePublicKey);
        var imported = NSec.Cryptography.PublicKey.Import(
            Algorithm,
            remotePublicKey,
            KeyBlobFormat.RawPublicKey);
        var creationParameters = new SharedSecretCreationParameters
        {
            ExportPolicy = KeyExportPolicies.AllowPlaintextExport,
        };
        using var secret = Algorithm.Agree(_privateKey, imported, in creationParameters);
        if (secret is null) throw new CryptographicException("Accordo X25519 non riuscito.");

        var rawSecret = secret.Export(SharedSecretBlobFormat.RawSharedSecret);
        var ordered = OrderKeys(PublicKey, remotePublicKey.ToArray());
        var infoPrefix = Encoding.UTF8.GetBytes("GTAControl-Session-v1");
        var info = new byte[infoPrefix.Length + 64];
        infoPrefix.CopyTo(info, 0);
        ordered.First.CopyTo(info, infoPrefix.Length);
        ordered.Second.CopyTo(info, infoPrefix.Length + 32);
        try
        {
            return HkdfSha256(rawSecret, Encoding.UTF8.GetBytes("GTAControl-HKDF-Salt-v1"), info, 32);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(rawSecret);
        }
    }

    public void Dispose() => _privateKey.Dispose();

    private static void ValidatePublicKey(ReadOnlySpan<byte> value)
    {
        if (value.Length != 32) throw new CryptographicException("Chiave pubblica X25519 non valida.");
    }

    private static (byte[] First, byte[] Second) OrderKeys(byte[] first, byte[] second) =>
        first.AsSpan().SequenceCompareTo(second) < 0 ? (first, second) : (second, first);

    internal static byte[] HkdfSha256(byte[] input, byte[] salt, byte[] info, int outputLength)
    {
        using var extract = new HMACSHA256(salt);
        var pseudorandomKey = extract.ComputeHash(input);
        var output = new byte[outputLength];
        var previous = Array.Empty<byte>();
        var written = 0;
        byte counter = 1;
        try
        {
            while (written < outputLength)
            {
                using var expand = new HMACSHA256(pseudorandomKey);
                var blockInput = new byte[previous.Length + info.Length + 1];
                previous.CopyTo(blockInput, 0);
                info.CopyTo(blockInput, previous.Length);
                blockInput[^1] = counter++;
                var next = expand.ComputeHash(blockInput);
                CryptographicOperations.ZeroMemory(previous);
                previous = next;
                var count = Math.Min(previous.Length, outputLength - written);
                previous.AsSpan(0, count).CopyTo(output.AsSpan(written));
                written += count;
            }
            return output;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(previous);
            CryptographicOperations.ZeroMemory(pseudorandomKey);
        }
    }
}
