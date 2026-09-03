using GTABridge.Windows.Storage;

namespace GTABridge.Windows;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (TryConfigureGameDirectory(args)) return;

        using var singleInstance = new Mutex(true, @"Local\GodMode.Mod.Remote.Control.Windows", out var isFirstInstance);
        if (!isFirstInstance)
        {
            MessageBox.Show(
                LocalizedText.Choose(
                    "GodMode Mod Remote Control è già in esecuzione nell'area di notifica.",
                    "GodMode Mod Remote Control is already running in the notification area."),
                "GodMode Mod Remote Control",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return;
        }
        ApplicationConfiguration.Initialize();
        Application.Run(new BridgeApplicationContext());
    }

    private static bool TryConfigureGameDirectory(string[] args)
    {
        if (args.Length != 2 || !string.Equals(args[0], "--configure-gta", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var gameDirectory = Path.GetFullPath(args[1]);
        if (!GameInstallationLocator.IsValid(gameDirectory))
        {
            MessageBox.Show(
                LocalizedText.Choose(
                    "La cartella scelta dall'installer non contiene GTA5.exe.",
                    "The folder selected by the setup does not contain GTA5.exe."),
                "GodMode Mod Remote Control",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            Environment.ExitCode = 2;
            return true;
        }

        var store = new AppSettingsStore();
        store.Save(store.Load() with { GameDirectory = gameDirectory });
        return true;
    }
}
