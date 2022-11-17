//
//  EncryptedStore.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 15.11.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import Foundation

import CommonCrypto
import CryptoKit

typealias EthPrivateKey = String

protocol EncryptedStore {
    func initialSetup() throws
    func `import`(privateKey: EthPrivateKey)
    func delete(address: Address)
    func sign(data: Data, address: Address, password: String) -> Signature
    func verify()
    func changePassword(from oldPassword: String, to newPassword: String)
    func changeSettings()
}


class SEncryptedStore {
    // internal store
    // sensitive store

    func add() {
        // protection -> store -> add()
    }

    func find() {
        // protection -> store -> find()
    }

    func delete() {
        // protection -> store -> delete()
    }
}

class SProtectedStore {
//    let index: SKeyIndex
    // keychain store
    // coder

    // cached data key

    // cache key
    // clear cache

    func add() {
        // get encryption data key
        // encrypt data with it
        // store encrypted data
    }

    func find() {
        // get encrypted data
        // get decrypted data key
            // if cached then return cached version
            // get encrypted decryption data key
            // get key decryption key
            // decrypt data key with decryption key
        // decrypt data with data key
        // return decrypted data
    }

    func delete() {
        // delete encrypted data
    }
}

struct SKeyIndex {
    var encryptData: String
    var encryptKey: String
    var decryptKey: String
    var decryptData: String

    var dataID: (_ id: String) -> String
}

struct SItemIDIndex {
    let keychainServiceID = "ksid"

    // secure enclave
    let sensitivePrivateKEK = "sks"
    let sensitivePublicKEK = "spk"

    let sensitivePrivateDEK = "sds" // encrypted
    let sensitivePublicDEK = "spd"

    // secure enclave
    let internalPrivateKEK = "iks"
    let internalPublicKEK = "ipk"

    let internalSymmetricDEK = "isd" // encrypted

    // encrypted
    func sensitiveData(_ id: String) -> String {
        "sd:\(id)"
    }

    // encrypted
    func internalData(_ id: String) -> String {
        "id:\(id)"
    }
}


class SCoder {
    func encrypt() {

    }

    func decrypt() {

    }
}
