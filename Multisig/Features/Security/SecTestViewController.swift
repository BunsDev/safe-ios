//
//  SecTestViewController.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 25.10.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import UIKit

class SecTestViewController: UIViewController {

    @IBOutlet weak var keyIDValueLabel: UILabel!

    var keyID: String? = "MYKEY" {
        didSet {
            guard isViewLoaded else { return }
            update()
        }
    }
    var key: SecKey?
    func tag(_ keyID: String) -> String { "io.gnosis.safe." + keyID }

    let store = MySecStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        update()
    }

    func update() {
        keyIDValueLabel.text = keyID ?? "not set"
    }

    @IBAction func createKey() {
        do {
            let keyID: String
            if self.keyID == nil {
                keyID = UUID().uuidString
            } else {
                keyID = self.keyID!
            }
            key = try store.createKey(tag: tag(keyID))
            self.keyID = keyID
        } catch {
            LogService.shared.error("Create error: \(error)")
            // -128 when user 'cancel's the application password
            // password asked to enter twice
        }
    }

    @IBAction func deleteKey() {
        guard let keyID = keyID else {
            return
        }
        do {
            try store.deleteKey(tag: tag(keyID))
            self.keyID = nil
            self.key = nil
        } catch {
            LogService.shared.error("Delete error: \(error)")
        }
    }

    @IBAction func findKey() {
        guard let keyID = keyID else {
            return
        }
        do {
            key = try store.findKey(tag: tag(keyID))
            if let key = key {
                let algo: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256
                guard SecKeyIsAlgorithmSupported(key, .sign, algo) else {
                    LogService.shared.error("Algo not supported")
                    return
                }
                var error: Unmanaged<CFError>?
                let data = "My Data".data(using: .utf8)!
                guard let sig = SecKeyCreateSignature(key, algo, data as CFData, &error) else {
                    throw error!.takeRetainedValue() as Error
                }
                LogService.shared.debug("Signature: \((sig as Data).toHexStringWithPrefix())")
            } else {
                self.keyID = nil
            }
        } catch {
            LogService.shared.error("Find error: \(error)")
        }
    }

}
