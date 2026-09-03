using GTABridge.Windows.Game;
using Xunit;

namespace GTAControlCore.Windows.Tests;

public sealed class GameModStateProviderTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), $"gta-remote-{Guid.NewGuid():N}");

    public GameModStateProviderTests() => Directory.CreateDirectory(_directory);

    [Fact]
    public void ReadsFreshAsiState()
    {
        File.WriteAllText(
            Path.Combine(_directory, "GTARemoteBridge.state"),
            "version=1\ngodMode=1\nwreckPreservation=0\npreservedWreckCount=3\n");
        var state = new GameModStateProvider(() => _directory).CurrentState();
        Assert.True(state.IsDirectControlReady);
        Assert.True(state.GodModeEnabled);
        Assert.False(state.WreckPreservationEnabled);
        Assert.Equal(3, state.PreservedWreckCount);
    }

    [Fact]
    public void RejectsStaleAsiStateAndDoesNotWriteCommand()
    {
        var statePath = Path.Combine(_directory, "GTARemoteBridge.state");
        File.WriteAllText(statePath, "version=1\ngodMode=0\n");
        File.SetLastWriteTimeUtc(statePath, DateTime.UtcNow - TimeSpan.FromSeconds(3));
        var provider = new GameModStateProvider(() => _directory);
        Assert.False(provider.CurrentState().IsDirectControlReady);
        Assert.Throws<InvalidOperationException>(() => provider.SetGodMode(true));
        Assert.False(File.Exists(Path.Combine(_directory, "GTARemoteBridge.command")));
    }

    [Fact]
    public void WritesAsiCommandOnlyWhenStateIsFresh()
    {
        File.WriteAllText(Path.Combine(_directory, "GTARemoteBridge.state"), "version=1\ngodMode=0\n");
        new GameModStateProvider(() => _directory).SetGodMode(true);
        var command = File.ReadAllText(Path.Combine(_directory, "GTARemoteBridge.command"));
        Assert.Contains("action=setGodMode", command);
        Assert.Contains("enabled=1", command);
    }

    public void Dispose() => Directory.Delete(_directory, true);
}
