using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace GTABridge.Windows.Game;

internal sealed class ForegroundGameGuard(Func<string?> gameDirectory)
{
    public void Validate()
    {
        var window = GetForegroundWindow();
        if (window == IntPtr.Zero) throw new InvalidOperationException(LocalizedText.Choose(
            "Nessuna applicazione è in primo piano.",
            "No application is in the foreground."));
        _ = GetWindowThreadProcessId(window, out var processID);
        if (processID == 0) throw new Win32Exception(LocalizedText.Choose(
            "Impossibile identificare il processo in primo piano.",
            "The foreground process could not be identified."));

        using var process = Process.GetProcessById((int)processID);
        if (!string.Equals(process.ProcessName, "GTA5", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(LocalizedText.Choose(
                "GTA V non è l'applicazione in primo piano.",
                "GTA V is not the foreground application."));

        var configuredDirectory = gameDirectory();
        if (string.IsNullOrWhiteSpace(configuredDirectory))
            throw new InvalidOperationException(LocalizedText.Choose(
                "Seleziona prima la cartella di GTA V dal menu del bridge.",
                "Choose the GTA V folder from the bridge menu first."));

        string? executablePath;
        try
        {
            executablePath = process.MainModule?.FileName;
        }
        catch (Win32Exception)
        {
            executablePath = null;
        }

        if (executablePath is null || !IsInside(executablePath, configuredDirectory))
            throw new InvalidOperationException(LocalizedText.Choose(
                "Il processo GTA in primo piano non appartiene alla cartella autorizzata.",
                "The foreground GTA process is not inside the authorized folder."));
    }

    private static bool IsInside(string file, string directory)
    {
        var root = Path.TrimEndingDirectorySeparator(Path.GetFullPath(directory)) + Path.DirectorySeparatorChar;
        var candidate = Path.GetFullPath(file);
        return candidate.StartsWith(root, StringComparison.OrdinalIgnoreCase);
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processID);
}
