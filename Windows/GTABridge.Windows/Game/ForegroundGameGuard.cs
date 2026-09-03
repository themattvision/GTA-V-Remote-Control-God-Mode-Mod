using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace GTABridge.Windows.Game;

internal sealed class ForegroundGameGuard(Func<string?> gameDirectory)
{
    public void Validate()
    {
        var window = GetForegroundWindow();
        if (window == IntPtr.Zero) throw new InvalidOperationException("Nessuna applicazione è in primo piano.");
        _ = GetWindowThreadProcessId(window, out var processID);
        if (processID == 0) throw new Win32Exception("Impossibile identificare il processo in primo piano.");

        using var process = Process.GetProcessById((int)processID);
        if (!string.Equals(process.ProcessName, "GTA5", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("GTA V non è l'applicazione in primo piano.");

        var configuredDirectory = gameDirectory();
        if (string.IsNullOrWhiteSpace(configuredDirectory))
            throw new InvalidOperationException("Seleziona prima la cartella di GTA V dal menu del bridge.");

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
            throw new InvalidOperationException("Il processo GTA in primo piano non appartiene alla cartella autorizzata.");
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
