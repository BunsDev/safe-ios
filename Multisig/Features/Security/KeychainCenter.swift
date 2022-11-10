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

class KeychainCenter {

    private var sensitiveKey: Data? = nil
   // private var sensitivePublicKey: SecKey? = nil

    init() {
        passcode = "<empty>"
    }

    var passcode: String

    // store passcode. Either if it random (user didn't give a password) or the user asked us to remember it
    func storePasscode(derivedPasscode: String) {
        //App.shared.snackbar.show(message: "storePasscode(): derivedPasscode: \(derivedPasscode)")

        // TODO Persist password



        passcode = derivedPasscode
    }

    func retrievePasscode() -> String {
        //App.shared.snackbar.show(message: "retrievePasscode(): derivedPasscode: \(passcode)")
        return passcode
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
            App.shared.snackbar.show(message: "flags: .applicationPassword")
        }
        let key = try createSEKey(flags: flags, tag: "global.safe.sensitive.KEK", applicationPassword: applicationPassword)

        return key // return tag as well?
    }

    func storeSensitivePrivateKey(encryptedSensitiveKey: Data) {
        let tag = "global.safe.sensitive.private.key.as.encrypted.data"
        App.shared.snackbar.show(message: "storeSensitiveKey(): secKey: \(encryptedSensitiveKey)")

        // TODO save encrypted sensitive_key to to keychain
        // safe to Keychain (as type password?) using SecItemAdd()
        //SecItemAdd()
        sensitiveKey = encryptedSensitiveKey
    }

    func storeSensitivePublicKey(publicKey: SecKey) throws {
        let tag = "global.safe.sensitive.public.key"
        App.shared.snackbar.show(message: "storeSensitivePublicKey(): publicKey: \(publicKey)")
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as? Data else {
            throw error!.takeRetainedValue() as Error
        }

        let addQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                       kSecAttrApplicationTag as String: tag,
                                       kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                       kSecValueRef as String: publicKey]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw GSError.GenericPasscodeError(reason: "Cannot store public key") } // Should be a new and more specific error type
        LogService.shared.error(" --> storeSensitivePublicKey: status: \(status)")

        // sensitivePublicKey = publicKey


        // decode key for debugging
        let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                      kSecAttrApplicationTag as String: tag]
        //var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData,
                options as CFDictionary,
                &error) else {
            throw error!.takeRetainedValue() as Error
        }
        LogService.shared.error(" --> storeSensitivePublicKey: decoded key: \(key)")

    }

//    func retrieveSensitivePublicKey() throws -> SecKey {
//        let tag = "global.safe.sensitive.public.key"
//        //App.shared.snackbar.show(message: "storeSensitivePublicKey(): publicKey: \(publicKey)")
//        var error: Unmanaged<CFError>?
//        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as? Data else {
//            throw error!.takeRetainedValue() as Error
//        }
//
//        let addQuery: [String: Any] = [kSecClass as String: kSecClassKey,
//                                       kSecAttrApplicationTag as String: tag,
//                                       kSecValueRef as String: publicKey]
//        let status = SecItemAdd(addQuery as CFDictionary, nil)
//        guard status == errSecSuccess else { throw GSError.GenericPasscodeError(reason: "Cannot store public key") } // Should be a new and more specific error type
//        LogService.shared.error(" --> storeSensitivePublicKey: status: \(status)")
//
//        // sensitivePublicKey = publicKey
//
//
//
//
//    }

    private func createSEKey(flags: SecAccessControlCreateFlags, tag: String, applicationPassword: String) throws -> SecKey {
        // Passed via kSecUseAuthenticationContext to kSecPrivateKeyAttrs attributes
        let authenticationContext = LAContext()
        let applicationPassword = applicationPassword.data(using: .utf8)
        // setCredential() returns false on the Simulator but at the same time SecureEnclave.isAvaliable is true
        let result = authenticationContext.setCredential(applicationPassword, type: .applicationPassword)
        App.shared.snackbar.show(message: "setCredential(): \(result)")

        let protection: CFString = kSecAttrAccessibleWhenUnlocked
        // create access control flags with params
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleAlways, // TODO necessary? useful? Available: kSecAttrAccessibleWhenPasscodeSet ?
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
        guard let privateKey = SecKeyCreateRandomKey(attributes, &createError) else {
            LogService.shared.error(" --> CreateError: \(createError)")
            throw createError!.takeRetainedValue() as Error
        }
        return privateKey
    }

    // used to find a KEK or a private key
    func findPrivateKey() {}

    func findPublicKey() {}

    func deleteItem(tag: String) {}

    func saveItem(data: Data, tag: String) {}

    func findItem(tag: String) -> Data? {
        preconditionFailure()
    }

    func encrypt() {

    }

    func decrypt() {
    }

}
