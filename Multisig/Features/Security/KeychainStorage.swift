//
//  KeychainCenter.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 02.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import CommonCrypto
import LocalAuthentication

class KeychainStorage {

    static let sensitivePublicKeyTag = "global.safe.sensitive.public.key"
    static let sensitiveEncryptedPrivateKeyTag = "global.safe.sensitive.private.key.as.encrypted.data"
    static let derivedPasswordTag = "global.safe.password.as.data"
    static let sensitiveKekTag = "global.safe.sensitive.KEK"

    // store passcode. Either if it random (user didn't give a password) or the user asked us to remember it
    func storePasscode(derivedPasscode: String) {
        // Store encrypted Password data
        storePasswordData(passwordData: derivedPasscode.data(using: .utf8)!)
    }

    func retrievePasscode() -> String? {
        // Retrieve password from persistence
        do {
            if let passCodeData = try findPasswordData() {
                return String.init(data: passCodeData, encoding: .utf8)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    private func storePasswordData(passwordData: Data) {
        // delete existing sensitive key data
        deleteData(KeychainStorage.derivedPasswordTag)
        // Create query
        let addPasswordDataQuery = [
            kSecValueData: passwordData,
            kSecClass: kSecClassGenericPassword, // right class?
            kSecAttrService: "private_key",
            kSecAttrAccount: KeychainStorage.derivedPasswordTag,
        ] as CFDictionary

        // safe to Keychain (as type password?) using SecItemAdd() and sensitiveEncryptedPrivateKeyTag
        let status = SecItemAdd(addPasswordDataQuery, nil) // TODO consider passing error ref instead of nil

        if status != errSecSuccess {
            // Print out the error
            LogService.shared.error("Error: \(status)")
        }
    }

    private func findPasswordData() throws -> Data? {
        let query = [
            kSecAttrService: "private_key",
            kSecAttrAccount: KeychainStorage.derivedPasswordTag,
            kSecClass: kSecClassGenericPassword,
            kSecReturnAttributes as String: false,
            kSecReturnData as String: true
        ] as CFDictionary

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)

        switch status {
        case errSecSuccess:
            if let item = item {
                let encryptedPrivateKeyData = item as! Data
                return encryptedPrivateKeyData
            } else {
                return nil
            }

        case errSecItemNotFound:
            return nil

        case let status:
            let message = SecCopyErrorMessageString(status, nil) as? String ?? String(status)
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
            throw error
        }
    }

    // used to create KEK
    func createSecureEnclaveKey(
            useBiometry: Bool,
            canChangeBiometry: Bool,
            applicationPassword: String
    ) throws -> SecKey {

        //create flags from booleans
        var flags: SecAccessControlCreateFlags = []
        if canChangeBiometry && useBiometry {
            flags = [.biometryAny, .or, .devicePasscode, .applicationPassword]
        }
        if !canChangeBiometry && useBiometry {
            flags = [.biometryCurrentSet, .or, .devicePasscode, .applicationPassword]
        }
        if !useBiometry {
            flags = [.applicationPassword]
            LogService.shared.debug(" --> flags: .applicationPassword")
        }
        let key = try createSEKey(flags: flags, tag: KeychainStorage.sensitiveKekTag, applicationPassword: applicationPassword)

        return key // return tag as well?
    }

    func storeSensitivePrivateKey(encryptedSensitiveKey: Data) {
        // delete existing sensitive key data
        deleteData(KeychainStorage.sensitiveEncryptedPrivateKeyTag)
        // Create query
        let addEncryptedDataQuery = [
            kSecValueData: encryptedSensitiveKey,
            kSecClass: kSecClassGenericPassword, // right class?
            kSecAttrService: "private_key",
            kSecAttrAccount: KeychainStorage.sensitiveEncryptedPrivateKeyTag,
        ] as CFDictionary


        // safe to Keychain (as type password?) using SecItemAdd() and sensitiveEncryptedPrivateKeyTag
        let status = SecItemAdd(addEncryptedDataQuery, nil) // TODO consider passing error ref instead of nil

        if status != errSecSuccess {
            // Print out the error
            LogService.shared.error("Error: \(status)")
        }
    }

    func retrieveEncryptedSensitivePrivateKeyData() throws -> Data? {

        let query = [
            kSecAttrService: "private_key",
            kSecAttrAccount: KeychainStorage.sensitiveEncryptedPrivateKeyTag,
            kSecClass: kSecClassGenericPassword,
            kSecReturnAttributes as String: false,
            kSecReturnData as String: true
        ] as CFDictionary

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)

        switch status {
        case errSecSuccess:
            if let item = item {
                let encryptedPrivateKeyData = item as! Data
                return encryptedPrivateKeyData
            } else {
                return nil
            }

        case errSecItemNotFound:
            return nil

        case let status:
            let message = SecCopyErrorMessageString(status, nil) as? String ?? String(status)
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
            throw error
        }
    }

    func deleteData(_ account: String) {
        let query = [
            kSecAttrService: "private_key",
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary

        // TODO Check for errors. Ignore nothing deleted
        SecItemDelete(query)
    }

    func storeSensitivePublicKey(publicKey: SecKey) throws {
        deleteItem(tag: KeychainStorage.sensitivePublicKeyTag)
        let addPublicKeyQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                kSecAttrApplicationTag as String: KeychainStorage.sensitivePublicKeyTag,
                                                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                                kSecValueRef as String: publicKey]
        let status = SecItemAdd(addPublicKeyQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GSError.GenericPasscodeError(reason: "Cannot store public key")
        } // Should be a new and more specific error type
    }

    func retrieveSensitivePublicKey() throws -> SecKey? {
        try findKey(tag: KeychainStorage.sensitivePublicKeyTag)
    }

    private func createSEKey(flags: SecAccessControlCreateFlags, tag: String, applicationPassword: String) throws -> SecKey {
        // Passed via kSecUseAuthenticationContext to kSecPrivateKeyAttrs attributes
        let authenticationContext = LAContext()
        let applicationPassword = applicationPassword.data(using: .utf8)
        // setCredential() returns false on the Simulator but at the same time SecureEnclave.isAvailable is true
        let result = authenticationContext.setCredential(applicationPassword, type: .applicationPassword)

        // create access control flags with params
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleAfterFirstUnlock, // TODO necessary? useful? Available: kSecAttrAccessibleWhenPasscodeSet ?
                .privateKeyUsage.union(flags),
                &accessError
        )
        else {
            throw accessError!.takeRetainedValue() as Error
        }

        // create attributes dictionary
        let attributes: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag.data(using: .utf8)!,
                kSecAttrAccessControl: access,
                kSecUseAuthenticationContext: authenticationContext
            ]
        ]

        // create a key pair
        var createError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes, &createError) else {
            throw createError!.takeRetainedValue() as Error
        }

        return privateKey
    }


    // used to create a public-private key pair (asymmetric) NOT in secure enclave -> Sensitive Key
    func createKeyPair() throws -> SecKey {
        let attributes: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ]
        var createError: Unmanaged<CFError>?
        guard let keyPair = SecKeyCreateRandomKey(attributes, &createError) else {
            LogService.shared.error("CreateError: \(createError)")
            throw createError!.takeRetainedValue() as Error
        }
        return keyPair
    }

    // used to find a KEK or a private key
    func findPrivateKey() {
    }

    func findPublicKey() {
    }

    func deleteItem(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)

        // TODO handle errors

//        if let   status == errSecSuccess || status == errSecItemNotFound else {
//            LogService.shared.error(" --> SecItemDelete failed with status: \(status)")
//
//        }
    }

    func saveItem(data: Data, tag: String) {
    }

    func findItem(tag: String) -> Data? {
        preconditionFailure()
    }

    func encrypt() {

    }

    func decrypt() {
    }


    func findKey(tag: String) throws -> SecKey? {
        // create search dictionary
        let getQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        // execute the search
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getQuery as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            let key = item as! SecKey
            return key

        case errSecItemNotFound:
            return nil

        case let status:
            let message = SecCopyErrorMessageString(status, nil) as? String ?? String(status)
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
            throw error
        }
    }

    func keyToString(key: SecKey) -> String {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as? Data else {
            LogService.shared.error("Error: \(error!.takeRetainedValue() as Error)")
            return "<error>"
        }
        return data.toHexString()
    }
}