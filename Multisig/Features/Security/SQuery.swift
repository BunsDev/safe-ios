//
//  Draft0.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 17.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import LocalAuthentication

enum SQuery {
    case generic(id: String, service: String)
    case ecKey(tag: String, password: Data?)

    func searchQuery() -> NSDictionary {
        var result: NSMutableDictionary

        switch self {
        case let .generic(id, service):
            result = [
                kSecAttrService: service,
                kSecAttrAccount: id,
                kSecClass: kSecClassGenericPassword,
                kSecReturnAttributes: false
            ]

        case let .ecKey(tag, password):
            result = [
                kSecClass: kSecClassKey,
                kSecAttrApplicationTag: tag.data(using: .utf8)!,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            ]
            if let context = LAContext(password: password) {
                result[kSecUseAuthenticationContext] = context
            }
        }

        result[kSecReturnRef] = true

        return result
    }

}

fileprivate extension LAContext {
    convenience init?(password: Data?) {
        guard let appPassword = password else { return nil }
        self.init()
        let success = setCredential(appPassword, type: .applicationPassword)
        guard success else { return nil }
    }
}

enum SItem {
    case generic(id: String, service: String, data: Data)
    case enclaveKey(tag: String)
    case ecKey(tag: String)

    // applies access flags and password to any type of item
    func attributes(access: SecAccessControlCreateFlags, password: Data?) throws -> NSDictionary {
        var result: NSMutableDictionary = [:]
        switch self {
        case let .generic(id, service, data):
            break

        case let .enclaveKey(tag):
            let accessControl = try accessControl(flags: .privateKeyUsage.union(access))

            // create private key attributes
            var privateKeyAttrs: NSMutableDictionary =  [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag.data(using: .utf8)!,
                kSecAttrAccessControl: accessControl
            ]

            if let context = LAContext(password: password) {
                privateKeyAttrs[kSecUseAuthenticationContext] = context
            }

            result = [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: 256,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs: privateKeyAttrs
            ]

        case let .ecKey(tag):
            break
        }

        return result
    }

    // create access control flags with params
    fileprivate func accessControl(flags: SecAccessControlCreateFlags) throws -> SecAccessControl {
        // SWIFT: can't extend SecAccessControl (compiler error that extensions of CF classes are not supported).

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleAfterFirstUnlock,
                flags,
                &accessError
        )
        else {
            throw accessError!.takeRetainedValue() as Error
        }
        return access
    }
}
