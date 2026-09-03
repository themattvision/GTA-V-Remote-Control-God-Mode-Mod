namespace GTABridge.Windows.Storage;

internal static class ProductStorage
{
    private const string CurrentDirectoryName = "GodMode Mod Remote Control";
    private const string LegacyDirectoryName = "GTA Remote Control";

    public static string LocalDataDirectory()
    {
        var root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var current = Path.Combine(root, CurrentDirectoryName);
        var legacy = Path.Combine(root, LegacyDirectoryName);

        if (!Directory.Exists(current) && Directory.Exists(legacy))
        {
            try
            {
                Directory.Move(legacy, current);
            }
            catch (IOException)
            {
                // Keep using a fresh directory if another process still owns the legacy folder.
            }
            catch (UnauthorizedAccessException)
            {
                // Keep using a fresh directory if Windows cannot migrate the legacy folder.
            }
        }

        Directory.CreateDirectory(current);
        return current;
    }
}
