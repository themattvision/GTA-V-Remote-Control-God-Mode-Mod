using Makaretu.Dns;

namespace GTABridge.Windows.Networking;

internal sealed class BonjourAdvertiser : IDisposable
{
    private readonly ServiceDiscovery _discovery = new();
    private ServiceProfile? _profile;

    public void Start(int port)
    {
        Stop();
        _profile = new ServiceProfile("GodMode Mod Remote Control", "_gtactrl._tcp", (ushort)port);
        _discovery.Advertise(_profile);
    }

    public void Stop()
    {
        if (_profile is null) return;
        _discovery.Unadvertise(_profile);
        _profile = null;
    }

    public void Dispose()
    {
        Stop();
        _discovery.Dispose();
    }
}
