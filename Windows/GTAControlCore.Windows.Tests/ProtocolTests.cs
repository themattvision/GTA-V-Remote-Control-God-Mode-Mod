using System.Text;
using System.Text.Json;
using GTAControlCore.Windows;
using Xunit;

namespace GTAControlCore.Windows.Tests;

public sealed class ProtocolTests
{
    [Fact]
    public void HelloUsesSwiftCompatibleWireShape()
    {
        var id = Guid.Parse("132ea4d8-f42a-4aec-921a-49b57738fefe");
        var json = Encoding.UTF8.GetString(ProtocolJson.Encode(WireMessage.Hello(id, PeerRole.Bridge)));
        using var document = JsonDocument.Parse(json);
        Assert.Equal("hello", document.RootElement.GetProperty("kind").GetString());
        var payload = document.RootElement.GetProperty("payload");
        Assert.Equal(3, payload.GetProperty("protocolVersion").GetInt32());
        Assert.Equal("bridge", payload.GetProperty("role").GetString());
        Assert.Equal(id, payload.GetProperty("peerID").GetGuid());
    }

    [Fact]
    public void DecoderAcceptsSwiftCommandJson()
    {
        const string json = """
        {"kind":"command","payload":{"envelope":{"clientID":"132EA4D8-F42A-4AEC-921A-49B57738FEFE","command":"moveUp","protocolVersion":3,"requestID":"D250A808-733A-44E7-A829-1186E0CD5494","sequence":2}}}
        """;
        var message = ProtocolJson.Decode(Encoding.UTF8.GetBytes(json));
        var command = Assert.IsType<CommandMessage>(message.Payload);
        Assert.Equal(TrainerCommand.MoveUp, command.Envelope.Command);
        Assert.Equal(2UL, command.Envelope.Sequence);
    }

    [Fact]
    public void FrameDecoderHandlesFragmentedAndCombinedFrames()
    {
        var first = FrameCodec.Encode(WireMessage.Hello(Guid.NewGuid(), PeerRole.Bridge));
        var second = FrameCodec.Encode(WireMessage.Heartbeat(1));
        var decoder = new FrameDecoder();
        Assert.Empty(decoder.Append(first.AsSpan(0, 3)));
        var tail = first.AsSpan(3).ToArray().Concat(second).ToArray();
        var frames = decoder.Append(tail);
        Assert.Equal(2, frames.Count);
    }

    [Fact]
    public void PairingDerivesTheSameSessionKeyOnBothSides()
    {
        using var bridge = new PairingKeyPair();
        using var phone = new PairingKeyPair();
        Assert.Equal(bridge.Fingerprint(phone.PublicKey), phone.Fingerprint(bridge.PublicKey));
        Assert.Equal(bridge.DeriveSessionKey(phone.PublicKey), phone.DeriveSessionKey(bridge.PublicKey));
    }

    [Fact]
    public void MatchesSwiftPairingVector()
    {
        using var first = new PairingKeyPair(Enumerable.Range(0, 32).Select(value => (byte)value).ToArray());
        using var second = new PairingKeyPair(Enumerable.Range(32, 32).Reverse().Select(value => (byte)value).ToArray());
        Assert.Equal(
            "8f40c5adb68f25624ae5b214ea767a6ec94d829d3d7b5e1ad1ba6f3e2138285f",
            Convert.ToHexString(first.PublicKey).ToLowerInvariant());
        Assert.Equal(
            "bf64bf0c8e37b3ecf7d4ae82e592a25c37b8a78ce450a721f3079c3372796e5c",
            Convert.ToHexString(second.PublicKey).ToLowerInvariant());
        Assert.Equal(105_389U, first.Fingerprint(second.PublicKey));
        Assert.Equal(
            "4165ae8cd29550fc66a3438e0aa958952294d9459235761beb0240c35bba5ae0",
            Convert.ToHexString(first.DeriveSessionKey(second.PublicKey)).ToLowerInvariant());
    }

    [Fact]
    public void SecureChannelsExchangeAuthenticatedHeartbeat()
    {
        using var bridgePair = new PairingKeyPair();
        using var phonePair = new PairingKeyPair();
        var key = bridgePair.DeriveSessionKey(phonePair.PublicKey);
        var sender = new SecureChannel(key);
        var receiver = new SecureChannel(key);
        var packet = sender.Seal(WireMessage.Heartbeat(1));
        var opened = receiver.Open(packet);
        Assert.Equal(new HeartbeatMessage(3, 1), Assert.IsType<HeartbeatMessage>(opened.Payload));
        Assert.Throws<InvalidDataException>(() => receiver.Open(packet));
    }

    [Fact]
    public void RateLimiterRejectsTwentyFirstCommandInOneSecond()
    {
        var limiter = new RateLimiter();
        var now = DateTimeOffset.UnixEpoch;
        for (var index = 0; index < 20; index++) Assert.True(limiter.Allow(now));
        Assert.False(limiter.Allow(now));
        Assert.True(limiter.Allow(now.AddSeconds(1)));
    }
}
