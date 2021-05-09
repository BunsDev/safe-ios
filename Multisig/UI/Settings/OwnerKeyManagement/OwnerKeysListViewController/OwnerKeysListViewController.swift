//
//  OwnerKeysListViewController.swift
//  Multisig
//
//  Created by Moaaz on 3/9/21.
//  Copyright © 2021 Gnosis Ltd. All rights reserved.
//

import UIKit
import WalletConnectSwift

class OwnerKeysListViewController: LoadableViewController, UITableViewDelegate, UITableViewDataSource {
    private var keys: [KeyInfo] = []
    private var addButton: UIBarButtonItem!
    override var isEmpty: Bool {
        keys.isEmpty
    }

    private var walletPerTopic = [String: InstalledWallet]()
    private var waitingForSession = false
    
    convenience init() {
        self.init(namedClass: LoadableViewController.self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Owner Keys"
        tableView.delegate = self
        tableView.dataSource = self

        tableView.backgroundColor = .primaryBackground

        tableView.registerCell(OwnerKeysListTableViewCell.self)
        tableView.registerCell(SigningKeyTableViewCell.self)

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 48

        emptyView.setText("There are no imported owner keys")
        emptyView.setImage(#imageLiteral(resourceName: "ico-no-keys"))

        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAddButton(_:)))
        navigationItem.rightBarButtonItem = addButton

        notificationCenter.addObserver(
            self,
            selector: #selector(lazyReloadData),
            name: .ownerKeyImported,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(lazyReloadData),
            name: .ownerKeyRemoved,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(lazyReloadData),
            name: .ownerKeyUpdated,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(walletConnectSessionCreated(_:)),
            name: .wcDidConnectClient,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(reload),
            name: .wcDidDisconnectClient,
            object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackEvent(.ownerKeysList)
    }

    @objc private func didTapAddButton(_ sender: Any) {
        var controller: UIViewController
        if App.configuration.toggles.walletConnectEnabled {
            controller = ViewControllerFactory.selectKeyTypeViewController(presenter: self)
        } else {
            controller = ViewControllerFactory.importOwnerViewController(presenter: self)
        }
        present(controller, animated: true)
    }

    override func reloadData() {
        super.reloadData()
        keys = (try? KeyInfo.all()) ?? []
        setNeedsReload(false)
        onSuccess()
        tableView.reloadData()
    }

    @objc private func walletConnectSessionCreated(_ notification: Notification) {
        guard waitingForSession else { return }
        waitingForSession = false

        guard let session = notification.object as? Session,
              let account = Address(session.walletInfo?.accounts.first ?? ""),
              keys.first(where: { $0.address == account }) != nil else {
            WalletConnectClientController.shared.disconnect()
            DispatchQueue.main.async { [unowned self] in
                self.hidePresentedIfNeeded()
                App.shared.snackbar.show(message: "Wrong wallet connected. Please try again.")
            }
            return
        }

        DispatchQueue.main.async { [unowned self] in
            // we need to update to always properly refresh session.walletInfo.peedId
            // that we use to identify if the wallet is connected
            _ = PrivateKeyController.updateKey(session: session,
                                               installedWallet: walletPerTopic[session.url.topic])

            if let presented = presentedViewController {
                // QR code controller
                presented.dismiss(animated: false, completion: nil)
            }

            App.shared.snackbar.show(message: "Owner key wallet connected")
            tableView.reloadData()
        }
    }

    @objc private func reload() {
        DispatchQueue.main.async { [unowned self] in
            self.reloadData()
        }
    }

    private func hidePresentedIfNeeded() {
        if let presented = presentedViewController {
            presented.dismiss(animated: false, completion: nil)
        }
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        keys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let keyInfo = keys[indexPath.row]
        if App.configuration.toggles.walletConnectEnabled {
            let cell = tableView.dequeueCell(SigningKeyTableViewCell.self, for: indexPath)
            cell.selectionStyle = .none
            cell.configure(keyInfo: keyInfo)
            return cell
        } else {
            let cell = tableView.dequeueCell(OwnerKeysListTableViewCell.self, for: indexPath)
            cell.set(address: keyInfo.address, title: keyInfo.displayName)
            cell.delegate = self
            return cell
        }
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if App.configuration.toggles.walletConnectEnabled {
            let vc = EditOwnerKeyViewController(keyInfo: keys[indexPath.row])
            show(vc, sender: self)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard App.configuration.toggles.walletConnectEnabled else { return nil }

        let keyInfo = keys[indexPath.row]

        var actions = [UIContextualAction]()
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [unowned self] _, _, completion in
            let vc = EditOwnerKeyViewController(keyInfo: self.keys[indexPath.row])
            self.show(vc, sender: self)
            completion(true)
        }
        actions.append(editAction)

        if keyInfo.keyType == .walletConnect {
            let isConnected = WalletConnectClientController.shared.isConnected(keyInfo: keyInfo)

            let wcAction = UIContextualAction(style: .normal, title: isConnected ? "Disconnect" : "Connect") {
                [unowned self] _, _, completion in

                if isConnected {
                    WalletConnectClientController.shared.disconnect()
                } else {
                    // try to reconnect
                    if let installedWallet = keyInfo.installedWallet {
                        self.reconnectWithInstalledWallet(installedWallet)
                    } else {
                        self.showConnectionQRCodeController()
                    }
                }

                completion(true)
            }
            wcAction.backgroundColor = isConnected ? .orange : .button
            actions.append(wcAction)
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _, _, completion in
            self.remove(key: keyInfo)
            completion(true)
        }
        actions.append(deleteAction)

        return UISwipeActionsConfiguration(actions: actions)
    }

    private func remove(key: KeyInfo) {
        let alertController = UIAlertController(
            title: nil,
            message: "Removing the owner key only removes it from this app. It doesn’t delete any Safes from this app or from blockchain. Transactions for Safes controlled by this key will no longer be available for signing in this app.",
            preferredStyle: .actionSheet)
        let remove = UIAlertAction(title: "Remove", style: .destructive) { _ in
            PrivateKeyController.remove(keyInfo: key)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(remove)
        alertController.addAction(cancel)
        present(alertController, animated: true)
    }

    private func reconnectWithInstalledWallet(_ installedWallet: InstalledWallet) {
        do {
            let (topic, connectionURL) = try WalletConnectClientController.shared
                .getTopicAndConnectionURL(universalLink: installedWallet.universalLink)
            walletPerTopic[topic] = installedWallet
            waitingForSession = true
            // we need a delay so that WalletConnectClient can send handshake request
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) {
                UIApplication.shared.open(connectionURL, options: [:], completionHandler: nil)
            }
        } catch {
            App.shared.snackbar.show(
                error: GSError.error(description: "Could not create connection URL", error: error))
        }
    }

    private func showConnectionQRCodeController() {
        do {
            let connectionURI = try WalletConnectClientController.shared.connect().absoluteString
            let qrCodeVC = WalletConnectQRCodeViewController.create(code: connectionURI)
            waitingForSession = true
            present(qrCodeVC, animated: true, completion: nil)
        } catch {
            App.shared.snackbar.show(
                error: GSError.error(description: "Could not create connection URL", error: error))
        }
    }
}

extension OwnerKeysListViewController: OwnerKeysListTableViewCellDelegate {
    func ownerKeysListTableViewDidEdit(cell: OwnerKeysListTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let vc = EditOwnerKeyViewController(keyInfo: keys[indexPath.row])
        show(vc, sender: self)
    }

    func ownerKeysListTableViewCellDidRemove(cell: OwnerKeysListTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        remove(key: keys[indexPath.row])
    }
}
