using System.Buffers.Binary;

namespace GTAControlCore.Windows;

public static class FrameCodec
{
    public static byte[] Encode(ReadOnlySpan<byte> payload)
    {
        if (payload.IsEmpty) throw new InvalidDataException("Frame vuoto.");
        if (payload.Length > ProtocolConstants.MaximumFrameBytes)
            throw new InvalidDataException("Frame troppo grande.");
        var frame = new byte[payload.Length + 4];
        BinaryPrimitives.WriteUInt32BigEndian(frame, (uint)payload.Length);
        payload.CopyTo(frame.AsSpan(4));
        return frame;
    }

    public static byte[] Encode(WireMessage message) => Encode(ProtocolJson.Encode(message));
    public static byte[] Encode(EncryptedPacket packet) =>
        Encode(System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(packet, ProtocolJson.Options));
}

public sealed class FrameDecoder
{
    private readonly List<byte> _buffer = [];

    public IReadOnlyList<byte[]> Append(ReadOnlySpan<byte> data)
    {
        _buffer.AddRange(data.ToArray());
        var frames = new List<byte[]>();
        while (_buffer.Count >= 4)
        {
            var header = _buffer.GetRange(0, 4).ToArray();
            var length = checked((int)BinaryPrimitives.ReadUInt32BigEndian(header));
            if (length <= 0 || length > ProtocolConstants.MaximumFrameBytes)
            {
                _buffer.Clear();
                throw new InvalidDataException("Lunghezza frame non valida.");
            }
            if (_buffer.Count < length + 4) break;
            frames.Add(_buffer.GetRange(4, length).ToArray());
            _buffer.RemoveRange(0, length + 4);
        }
        return frames;
    }
}
