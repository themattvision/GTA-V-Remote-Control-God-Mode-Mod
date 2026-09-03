using System.Security.Cryptography;
using System.Text.Json;
using GTAControlCore.Windows;

namespace GTABridge.Windows.Storage;

internal sealed class ProtectedSessionStore
{
    private static readonly byte[] Entropy = "GTAControl-Windows-Session-v1"u8.ToArray();
    private readonly string _path;
    private readonly object _gate = new();

    public ProtectedSessionStore()
    {
        var directory = ProductStorage.LocalDataDirectory();
        _path = Path.Combine(directory, "sessions.json");
    }

    public byte[]? Load(Guid clientID)
    {
        lock (_gate)
        {
            var sessions = Read();
            if (!sessions.TryGetValue(clientID, out var encoded)) return null;
            try
            {
                return ProtectedData.Unprotect(
                    Convert.FromBase64String(encoded),
                    Entropy,
                    DataProtectionScope.CurrentUser);
            }
            catch (Exception error) when (error is CryptographicException or FormatException)
            {
                sessions.Remove(clientID);
                Write(sessions);
                return null;
            }
        }
    }

    public void Save(Guid clientID, ReadOnlySpan<byte> sessionKey)
    {
        lock (_gate)
        {
            var sessions = Read();
            var plaintextKey = sessionKey.ToArray();
            byte[]? protectedKey = null;
            try
            {
                protectedKey = ProtectedData.Protect(
                    plaintextKey,
                    Entropy,
                    DataProtectionScope.CurrentUser);
                sessions[clientID] = Convert.ToBase64String(protectedKey);
                Write(sessions);
            }
            finally
            {
                CryptographicOperations.ZeroMemory(plaintextKey);
                if (protectedKey is not null) CryptographicOperations.ZeroMemory(protectedKey);
            }
        }
    }

    public void Remove(Guid clientID)
    {
        lock (_gate)
        {
            var sessions = Read();
            if (sessions.Remove(clientID)) Write(sessions);
        }
    }

    private Dictionary<Guid, string> Read()
    {
        if (!File.Exists(_path)) return [];
        try
        {
            return JsonSerializer.Deserialize<Dictionary<Guid, string>>(
                File.ReadAllBytes(_path), ProtocolJson.Options) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private void Write(Dictionary<Guid, string> sessions)
    {
        var temporaryPath = _path + ".tmp";
        File.WriteAllBytes(temporaryPath, JsonSerializer.SerializeToUtf8Bytes(sessions, ProtocolJson.Options));
        File.Move(temporaryPath, _path, true);
    }
}
