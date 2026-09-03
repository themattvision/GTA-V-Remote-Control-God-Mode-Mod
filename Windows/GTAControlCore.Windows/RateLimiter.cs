namespace GTAControlCore.Windows;

public sealed class RateLimiter
{
    private readonly Queue<DateTimeOffset> _events = new();
    private readonly object _gate = new();

    public bool Allow(DateTimeOffset? now = null)
    {
        lock (_gate)
        {
            var instant = now ?? DateTimeOffset.UtcNow;
            while (_events.TryPeek(out var oldest) && instant - oldest >= TimeSpan.FromSeconds(1))
                _events.Dequeue();
            if (_events.Count >= ProtocolConstants.MaximumCommandsPerSecond) return false;
            _events.Enqueue(instant);
            return true;
        }
    }
}
