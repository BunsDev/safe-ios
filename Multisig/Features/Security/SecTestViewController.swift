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

    var keyID: String? {
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
            let keyID = UUID().uuidString
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
            if key == nil {
                self.keyID = nil
            } else {
                LogService.shared.debug("Found")
            }
        } catch {
            LogService.shared.error("Find error: \(error)")
        }
    }

}
