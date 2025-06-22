import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    private let service = "com.voicetotext.app"
    
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedStatus(OSStatus)
    }
    
    // MARK: - Save
    
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Try to update first (in case the item already exists)
        let updateQuery: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return
        }
        
        // If update failed, try to add new item
        if updateStatus == errSecItemNotFound {
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }
    
    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        try save(data, for: key)
    }
    
    // MARK: - Retrieve
    
    func retrieve(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            guard let data = result as? Data else {
                throw KeychainError.invalidItemFormat
            }
            return data
        } else if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        return string
    }
    
    // MARK: - Delete
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Convenience Methods
    
    func exists(for key: String) -> Bool {
        do {
            _ = try retrieve(for: key)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Keychain Error Extensions

extension KeychainHelper.KeychainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidItemFormat:
            return "Invalid item format"
        case .unexpectedStatus(let status):
            return "Unexpected keychain status: \(status)"
        }
    }
}