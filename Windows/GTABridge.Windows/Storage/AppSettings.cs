using System.Text.Json;
using GTAControlCore.Windows;

namespace GTABridge.Windows.Storage;

internal sealed record AppSettings(Guid BridgeID, string? GameDirectory)
{
    public static AppSettings CreateDefault() => new(Guid.NewGuid(), GameInstallationLocator.TryLocate());
}

internal sealed class AppSettingsStore
{
    private readonly string _path;

    public AppSettingsStore()
    {
        var directory = ProductStorage.LocalDataDirectory();
        _path = Path.Combine(directory, "settings.json");
    }

    public AppSettings Load()
    {
        if (!File.Exists(_path))
        {
            return CreateAndSave();
        }

        try
        {
            return JsonSerializer.Deserialize<AppSettings>(File.ReadAllBytes(_path), ProtocolJson.Options)
                ?? CreateAndSave();
        }
        catch (JsonException)
        {
            return CreateAndSave();
        }
    }

    public void Save(AppSettings settings)
    {
        var temporaryPath = _path + ".tmp";
        File.WriteAllBytes(temporaryPath, JsonSerializer.SerializeToUtf8Bytes(settings, ProtocolJson.Options));
        File.Move(temporaryPath, _path, true);
    }

    private AppSettings CreateAndSave()
    {
        var created = AppSettings.CreateDefault();
        Save(created);
        return created;
    }
}

internal static class GameInstallationLocator
{
    public static string? TryLocate()
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Rockstar Games", "Grand Theft Auto V"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Steam", "steamapps", "common", "Grand Theft Auto V"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Epic Games", "GTAV"),
        };
        return candidates.FirstOrDefault(IsValid);
    }

    public static bool IsValid(string? directory) =>
        !string.IsNullOrWhiteSpace(directory) && File.Exists(Path.Combine(directory, "GTA5.exe"));
}
