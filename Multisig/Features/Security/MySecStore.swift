//
//  MySecStore.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 25.10.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation

class MySecStore {
    func createKey(protection: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly, flags: SecAccessControlCreateFlags = .applicationPassword, tag: String) throws -> SecKey {
        // create access control flags with params
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            protection,
            .privateKeyUsage.union(flags),
            &accessError
        ) else {
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
                kSecAttrAccessControl: access
            ]
        ]

        // create a key pair
        var createError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes, &createError) else {
            throw createError!.takeRetainedValue() as Error
        }

        return privateKey
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
}
