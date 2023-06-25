import Foundation
import CustomAuth
import UIKit

class LoginModel {
    var onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func loginWithCustomAuth(caller: UIViewController) {
        Task {
            let sub = SubVerifierDetails(loginType: .web,
                                         loginProvider: .google,
                                         clientId: App.configuration.web3auth.googleClientId,
                                         verifier: App.configuration.web3auth.googleVerifier,
                                         redirectURL: App.configuration.web3auth.redirectUrl
            )
            let tdsdk = CustomAuth(aggregateVerifierType: .singleLogin,
                                   aggregateVerifier: App.configuration.web3auth.googleVerifier,
                                   subVerifierDetails: [sub],
                                   network: .CYAN,
                                   loglevel: .debug
            )
            let data = try await tdsdk.triggerLogin(controller: caller)
            await MainActor.run(body: {
                print("privateKey: \(data["privateKey"] ?? "foo")")
                onClose()
                caller.closeModal()
            })
        }
    }

}
