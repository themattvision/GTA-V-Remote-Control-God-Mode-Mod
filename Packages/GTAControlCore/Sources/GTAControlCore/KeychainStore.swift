import Foundation
import Security

public enum KeychainStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidStoredKey
}

public struct KeychainSessionStore: Sendable {
    public let service: String
    public let accessGroup: String?

    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func save(_ sessionKey: SessionKey, for peerID: UUID) throws {
        let baseQuery = query(for: peerID)
        let update = [kSecValueData as String: sessionKey.rawRepresentation]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var insert = baseQuery
        insert[kSecValueData as String] = sessionKey.rawRepresentation
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    public func sessionKey(for peerID: UUID) throws -> SessionKey? {
        var lookup = query(for: peerID)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainStoreError.invalidStoredKey
        }
        do {
            return try SessionKey(rawRepresentation: data)
        } catch {
            throw KeychainStoreError.invalidStoredKey
        }
    }

    public func removeSessionKey(for peerID: UUID) throws {
        let status = SecItemDelete(query(for: peerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func query(for peerID: UUID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: peerID.uuidString,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

