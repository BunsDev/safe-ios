//
//  SKeychainStore.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 17.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation

class SKeychainStore {
    // input:
    //    - attributes: dictionary of parameters
    // output:
    //    - if error occurs, throws
    func create(attributes: NSDictionary) throws {
        
    }

    func delete() {

    }

    // input:
    //    - query: dictionary of parameters
    // output:
    //    - if query.class is password, then Data
    //    - if query.class is key, then SecKey
    //    - if error occurs, throws error
    func find(query: NSDictionary) throws -> AnyObject? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item

        case errSecItemNotFound:
            return nil

        case let status:
            throw error(status)
        }
    }

    private func error(_ status: OSStatus) -> Error {
        let message = SecCopyErrorMessageString(status, nil) as? String ?? String(status)
        let error = NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        return error
    }
}
