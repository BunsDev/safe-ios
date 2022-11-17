//
//  Draft2.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 17.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import LocalAuthentication

func useTQuery() {
    let k = TECKey(tag: "my tag", password: Data([1, 2, 3]))
    let g = TGeneric(id: "my id", service: "my service")
    let params = g.searchQuery()
}

class TQuery {
    func defaults() -> [String: Any] {
        [
            kSecReturnRef as String: true
        ]
    }

    func buildQuery() -> [String: Any] {
        [:]
    }

    func searchQuery() -> [String: Any] {
        let base = defaults()
        let query = buildQuery()
        // merge query on top of base and override duplicate keys with query's keys
        let result = base.merging(query) { _, new in
            new
        }
        return result
    }
}

class TGeneric: TQuery {
    internal init(id: String, service: String) {
        self.id = id
        self.service = service
    }

    var id: String
    var service: String

    override func buildQuery() -> [String : Any] {
        [
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: false
        ]
    }
}

class TECKey: TQuery {
    internal init(tag: String, password: Data? = nil) {
        self.tag = tag
        self.password = password
    }

    var tag: String
    var password: Data?

    override func buildQuery() -> [String : Any] {
        var result: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]
        if let context = lacontext() {
            result[kSecUseAuthenticationContext as String] = context
        }
        return result
    }

    func lacontext() -> LAContext? {
        guard let appPassword = password else { return nil }
        let context = LAContext()
        let success = context.setCredential(appPassword, type: .applicationPassword)
        guard success else { return nil }
        return context
    }
}
