//
//  Draft1.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 17.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import LocalAuthentication

func usePQuery() {
    let k = PECKey(tag: "my tag", password: Data([1, 2, 3]))
    let g = PGenericQuery(id: "my id", service: "my service")
    let params = g.searchQuery()
}

protocol PQuery {
    func searchQuery() -> [String: Any]

    // internal
    func buildQuery() -> [String: Any]
    func defaultParams() -> [String: Any]
}

extension PQuery {
    func searchQuery() -> [String: Any] {
        defaultParams().merging(buildQuery()) { _, new in
            new
        }
    }

    func defaultParams() -> [String: Any] {
        [
            kSecReturnRef as String: true
        ]
    }
}

struct PGenericQuery: PQuery {
    var id: String
    var service: String

    func buildQuery() -> [String : Any] {
        var result: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: false
        ]
        return result
    }
}

struct PECKey: PQuery {
    var tag: String
    var password: Data?

    func buildQuery() -> [String : Any] {
        var result: [String : Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]
        if let context = lacontext(password) {
            result[kSecUseAuthenticationContext as String] = context
        }
        return result
    }

    func lacontext(_ appPassword: Data?) -> LAContext? {
        guard let appPassword = appPassword else { return nil }
        let context = LAContext()
        let success = context.setCredential(appPassword, type: .applicationPassword)
        guard success else { return nil }
        return context
    }
}
