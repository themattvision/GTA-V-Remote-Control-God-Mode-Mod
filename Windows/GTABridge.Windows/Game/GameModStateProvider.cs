using GTAControlCore.Windows;

namespace GTABridge.Windows.Game;

internal sealed class GameModStateProvider(Func<string?> gameDirectory)
{
    public TrainerStateSnapshot CurrentState()
    {
        var directory = gameDirectory();
        if (string.IsNullOrWhiteSpace(directory)) return Unavailable();
        var statePath = Path.Combine(directory, "GTARemoteBridge.state");
        try
        {
            if (!File.Exists(statePath) || DateTime.UtcNow - File.GetLastWriteTimeUtc(statePath) >= TimeSpan.FromSeconds(2))
                return Unavailable();
            var values = Parse(File.ReadAllLines(statePath));
            if (values.GetValueOrDefault("version") != "1" || !TryBoolean(values.GetValueOrDefault("godMode"), out var godMode))
                return Unavailable();
            bool? wreck = TryBoolean(values.GetValueOrDefault("wreckPreservation"), out var wreckValue)
                ? wreckValue : null;
            int? count = int.TryParse(values.GetValueOrDefault("preservedWreckCount"), out var countValue)
                ? countValue : null;
            return new(true, godMode, wreck, count);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            return Unavailable();
        }
    }

    public void SetGodMode(bool enabled) => WriteRequest("setGodMode", enabled);
    public void SetWreckPreservation(bool enabled) => WriteRequest("setWreckPreservation", enabled);

    private void WriteRequest(string action, bool enabled)
    {
        if (!CurrentState().IsDirectControlReady)
            throw new InvalidOperationException("La modalità diretta non è pronta. Avvia GTA V in modalità Storia.");
        var directory = gameDirectory()!;
        var contents = $"version=1\nrequestID={Guid.NewGuid()}\naction={action}\nenabled={(enabled ? 1 : 0)}\n";
        var path = Path.Combine(directory, "GTARemoteBridge.command");
        var temporaryPath = path + ".tmp";
        File.WriteAllText(temporaryPath, contents);
        File.Move(temporaryPath, path, true);
    }

    private static Dictionary<string, string> Parse(IEnumerable<string> lines)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var line in lines)
        {
            var parts = line.Split('=', 2);
            if (parts.Length == 2) values[parts[0]] = parts[1];
        }
        return values;
    }

    private static bool TryBoolean(string? value, out bool result)
    {
        if (value is "1" or "true") { result = true; return true; }
        if (value is "0" or "false") { result = false; return true; }
        result = false;
        return false;
    }

    private static TrainerStateSnapshot Unavailable() => new(false, null, null, null);
}
