using GTAControlCore.Windows;
using GTABridge.Windows.Game;
using GTABridge.Windows.Networking;
using GTABridge.Windows.Storage;

namespace GTABridge.Windows;

internal sealed class BridgeApplicationContext : ApplicationContext
{
    private readonly SynchronizationContext _ui;
    private readonly NotifyIcon _trayIcon;
    private readonly ToolStripMenuItem _statusItem;
    private readonly ToolStripMenuItem _pairingItem;
    private readonly ToolStripMenuItem _approveItem;
    private readonly ToolStripMenuItem _rejectItem;
    private readonly AppSettingsStore _settingsStore = new();
    private readonly BridgeServer _server;
    private AppSettings _settings;
    private bool _closing;

    public BridgeApplicationContext()
    {
        _ui = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
        _settings = _settingsStore.Load();
        var guard = new ForegroundGameGuard(() => _settings.GameDirectory);
        var input = new TrainerInputInjector(guard);
        var mod = new GameModStateProvider(() => _settings.GameDirectory);
        _server = new BridgeServer(_settings.BridgeID, new ProtectedSessionStore(), input, mod);

        _statusItem = new ToolStripMenuItem(LocalizedText.Choose("Avvio…", "Starting…")) { Enabled = false };
        _pairingItem = new ToolStripMenuItem(LocalizedText.Choose("Codice pairing", "Pairing code")) { Enabled = false, Visible = false };
        _approveItem = new ToolStripMenuItem(LocalizedText.Choose("Approva pairing", "Approve pairing"), null, ResolvePairing) { Tag = true, Visible = false };
        _rejectItem = new ToolStripMenuItem(LocalizedText.Choose("Rifiuta pairing", "Reject pairing"), null, ResolvePairing) { Tag = false, Visible = false };
        var chooseDirectory = new ToolStripMenuItem(LocalizedText.Choose("Seleziona cartella GTA V…", "Choose GTA V folder…"), null, ChooseGameDirectory);
        var testTrainer = new ToolStripMenuItem(LocalizedText.Choose("Test F4 tra 3 secondi", "Test F4 in 3 seconds"), null, TestTrainer);
        var exit = new ToolStripMenuItem(LocalizedText.Choose("Esci", "Exit"), null, Exit);
        var menu = new ContextMenuStrip();
        menu.Items.AddRange([
            _statusItem,
            _pairingItem,
            _approveItem,
            _rejectItem,
            new ToolStripSeparator(),
            chooseDirectory,
            testTrainer,
            new ToolStripSeparator(),
            exit,
        ]);

        _trayIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "GodMode Mod Remote Control",
            ContextMenuStrip = menu,
            Visible = true,
        };

        _server.StatusChanged += status => Post(() => SetStatus(status));
        _server.Diagnostic += message => Post(() => SetStatus(message));
        _server.PairingRequested += (_, fingerprint) => Post(() => ShowPairing(fingerprint));
        _server.PairingCleared += () => Post(HidePairing);

        try
        {
            _server.Start();
        }
        catch (Exception error)
        {
            SetStatus($"{LocalizedText.Choose("Avvio fallito", "Startup failed")}: {error.Message}");
            MessageBox.Show(error.Message, "GodMode Mod Remote Control", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void ChooseGameDirectory(object? sender, EventArgs eventArgs)
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = LocalizedText.Choose("Seleziona la cartella che contiene GTA5.exe", "Choose the folder containing GTA5.exe"),
            UseDescriptionForTitle = true,
            SelectedPath = _settings.GameDirectory ?? string.Empty,
        };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        if (!GameInstallationLocator.IsValid(dialog.SelectedPath))
        {
            MessageBox.Show(
                LocalizedText.Choose("La cartella scelta non contiene GTA5.exe.", "The selected folder does not contain GTA5.exe."),
                "GodMode Mod Remote Control",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return;
        }
        _settings = _settings with { GameDirectory = dialog.SelectedPath };
        _settingsStore.Save(_settings);
        SetStatus(LocalizedText.Choose("Cartella GTA V verificata", "GTA V folder verified"));
    }

    private async void TestTrainer(object? sender, EventArgs eventArgs)
    {
        try
        {
            SetStatus(LocalizedText.Choose("Porta GTA V in primo piano, test fra 3 secondi", "Bring GTA V to the foreground, testing in 3 seconds"));
            await Task.Delay(TimeSpan.FromSeconds(3));
            var input = new TrainerInputInjector(new ForegroundGameGuard(() => _settings.GameDirectory));
            await input.InjectAsync(TrainerCommand.ToggleTrainer);
            SetStatus(LocalizedText.Choose("F4 inviato a GTA V", "F4 sent to GTA V"));
        }
        catch (Exception error)
        {
            SetStatus(error.Message);
            MessageBox.Show(error.Message, LocalizedText.Choose("Test trainer", "Trainer test"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private async void ResolvePairing(object? sender, EventArgs eventArgs)
    {
        if (sender is not ToolStripMenuItem { Tag: bool approved }) return;
        _approveItem.Enabled = false;
        _rejectItem.Enabled = false;
        try
        {
            await _server.ResolvePairingAsync(approved);
        }
        catch (Exception error)
        {
            SetStatus(error.Message);
        }
        finally
        {
            _approveItem.Enabled = true;
            _rejectItem.Enabled = true;
        }
    }

    private void ShowPairing(uint fingerprint)
    {
        _pairingItem.Text = $"{LocalizedText.Choose("Codice", "Code")}: {fingerprint:000000}";
        _pairingItem.Visible = true;
        _approveItem.Visible = true;
        _rejectItem.Visible = true;
    }

    private void HidePairing()
    {
        _pairingItem.Visible = false;
        _approveItem.Visible = false;
        _rejectItem.Visible = false;
    }

    private void SetStatus(string status)
    {
        _statusItem.Text = status.Length <= 80 ? status : status[..77] + "…";
        _trayIcon.Text = status.Length <= 63 ? status : status[..60] + "…";
    }

    private void Post(Action action) => _ui.Post(_ => action(), null);

    private async void Exit(object? sender, EventArgs eventArgs)
    {
        if (_closing) return;
        _closing = true;
        _trayIcon.Visible = false;
        await _server.DisposeAsync();
        _trayIcon.Dispose();
        ExitThread();
    }
}
