//
//  Draft0.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 17.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import LocalAuthentication

func useSQuery() {
    let k = SQuery.ecKey(tag: "my tag", password: Data([1, 2, 3]))
    let g = SQuery.generic(id: "my id", service: "my service")
    let params = g.searchQuery()
}

enum SQuery {
    case generic(id: String, service: String)
    case ecKey(tag: String, password: Data?)

    func searchQuery() -> [String: Any] {
        var result: [String: Any]

        switch self {
        case let .generic(id, service):
            result = [
                kSecAttrService as String: service,
                kSecAttrAccount as String: id,
                kSecClass as String: kSecClassGenericPassword,
                kSecReturnAttributes as String: false
            ]

        case let .ecKey(tag, password):
            result = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            ]
            if let context = lacontext(password) {
                result[kSecUseAuthenticationContext as String] = context
            }
        }

        result[kSecReturnRef as String] = true

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
