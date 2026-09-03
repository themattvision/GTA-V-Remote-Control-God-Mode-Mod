namespace GTABridge.Windows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var singleInstance = new Mutex(true, @"Local\GodMode.Mod.Remote.Control.Windows", out var isFirstInstance);
        if (!isFirstInstance)
        {
            MessageBox.Show(
                "GodMode Mod Remote Control è già in esecuzione nell'area di notifica.",
                "GodMode Mod Remote Control",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return;
        }
        ApplicationConfiguration.Initialize();
        Application.Run(new BridgeApplicationContext());
    }
}
