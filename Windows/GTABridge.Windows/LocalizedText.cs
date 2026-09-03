using System.Globalization;

namespace GTABridge.Windows;

internal static class LocalizedText
{
    private static bool UsesItalian =>
        string.Equals(CultureInfo.CurrentUICulture.TwoLetterISOLanguageName, "it", StringComparison.OrdinalIgnoreCase);

    public static string Choose(string italian, string english) => UsesItalian ? italian : english;
}
