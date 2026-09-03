import Foundation

public enum FrameCodecError: Error, Equatable, Sendable {
    case emptyPayload
    case frameTooLarge(actual: Int, maximum: Int)
    case malformedPayload
    case unsupportedVersion(received: UInt16, supported: UInt16)
}

public enum FrameCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encodePayload(encoder.encode(value))
    }

    public static func encodePayload(_ payload: Data) throws -> Data {
        guard !payload.isEmpty else { throw FrameCodecError.emptyPayload }
        guard payload.count <= ProtocolConstants.maximumFrameBytes else {
            throw FrameCodecError.frameTooLarge(
                actual: payload.count,
                maximum: ProtocolConstants.maximumFrameBytes
            )
        }

        let length = UInt32(payload.count)
        var framed = Data(capacity: MemoryLayout<UInt32>.size + payload.count)
        framed.append(UInt8((length >> 24) & 0xff))
        framed.append(UInt8((length >> 16) & 0xff))
        framed.append(UInt8((length >> 8) & 0xff))
        framed.append(UInt8(length & 0xff))
        framed.append(payload)
        return framed
    }
}

public struct FrameDecoder: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []

        while buffer.count >= MemoryLayout<UInt32>.size {
            let length = Int(
                UInt32(buffer[buffer.startIndex]) << 24
                    | UInt32(buffer[buffer.startIndex + 1]) << 16
                    | UInt32(buffer[buffer.startIndex + 2]) << 8
                    | UInt32(buffer[buffer.startIndex + 3])
            )

            guard length > 0 else {
                buffer.removeAll(keepingCapacity: true)
                throw FrameCodecError.emptyPayload
            }
            guard length <= ProtocolConstants.maximumFrameBytes else {
                buffer.removeAll(keepingCapacity: true)
                throw FrameCodecError.frameTooLarge(
                    actual: length,
                    maximum: ProtocolConstants.maximumFrameBytes
                )
            }

            let totalLength = MemoryLayout<UInt32>.size + length
            guard buffer.count >= totalLength else { break }
            frames.append(buffer.subdata(in: 4..<totalLength))
            buffer.removeSubrange(0..<totalLength)
        }

        return frames
    }
}

public enum ProtocolCodec {
    public static func encode(_ message: WireMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(message)
        guard payload.count <= ProtocolConstants.maximumFrameBytes else {
            throw FrameCodecError.frameTooLarge(
                actual: payload.count,
                maximum: ProtocolConstants.maximumFrameBytes
            )
        }
        return payload
    }

    public static func encodeFrame(_ message: WireMessage) throws -> Data {
        try FrameCodec.encodePayload(encode(message))
    }

    public static func decode(_ payload: Data) throws -> WireMessage {
        let message: WireMessage
        do {
            message = try JSONDecoder().decode(WireMessage.self, from: payload)
        } catch {
            throw FrameCodecError.malformedPayload
        }
        guard message.protocolVersion == ProtocolConstants.version else {
            throw FrameCodecError.unsupportedVersion(
                received: message.protocolVersion,
                supported: ProtocolConstants.version
            )
        }
        return message
    }
}

