//
//  RejectTransactionRequest.swift
//  Multisig
//
//  Created by Moaaz on 2/17/21.
//  Copyright © 2021 Gnosis Ltd. All rights reserved.
//

import Foundation

struct ProposeTransactionRequest: JSONRequest {
    let safe: AddressString
    let sender: AddressString
    let signature: String
    let transaction: Transaction

    enum CodingKeys: String, CodingKey {
        case sender
        case to
        case value
        case data
        case operation
        case safeTxGas
        case baseGas
        case gasPrice
        case gasToken
        case refundReceiver
        case nonce
        case contractTransactionHash
        case signature
    }

    var httpMethod: String { return "POST" }
    var urlPath: String { return "/v1/transactions/\(safe)/propose" }

    typealias ResponseType = EmptyResponse

    struct EmptyResponse: Decodable {
        // empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sender, forKey: .sender)
        try container.encode(transaction.to, forKey: .to)
        try container.encode(transaction.value, forKey: .value)
        try container.encode(transaction.data, forKey: .data)
        try container.encode(transaction.operation, forKey: .operation)
        try container.encode(transaction.safeTxGas, forKey: .safeTxGas)
        try container.encode(transaction.baseGas, forKey: .baseGas)
        try container.encode(transaction.gasPrice, forKey: .gasPrice)
        try container.encode(transaction.gasToken, forKey: .gasToken)
        try container.encode(transaction.refundReceiver, forKey: .refundReceiver)
        try container.encode(transaction.nonce, forKey: .nonce)
        try container.encode(transaction.safeTxHash, forKey: .contractTransactionHash)
        try container.encode(signature, forKey: .signature)
    }
}

extension SafeClientGatewayService {
    func propose(transaction: Transaction, safeAddress: AddressString, sender: AddressString, signature: String, completion: @escaping (Result<ProposeTransactionRequest.EmptyResponse, Error>) -> Void) -> URLSessionTask? {
        asyncExecute(request: ProposeTransactionRequest(safe: safeAddress, sender: sender, signature: signature, transaction: transaction), completion: completion)
    }
}
