//
//  SafeSettingsViewModel.swift
//  Multisig
//
//  Created by Moaaz on 5/6/20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import Foundation
import Combine

class SafeSettingsViewModel: LoadableViewModel {
    @Published
    var isLoading: Bool = true

    @Published
    var errorMessage: String? = nil

    @Published
    var safe: Safe

    private var subscribers = Set<AnyCancellable>()

    init(safe: Safe) {
        self.safe = safe
        reloadData()
    }

    func reloadData() {
        isLoading = true
        Just(safe.address)
            .compactMap { $0 }
            .compactMap { Address($0) }
            .setFailureType(to: Error.self)
            .flatMap { address in
                Future { promise in
                    DispatchQueue.global().async {
                        do {
                            let safeInfo = try Safe.download(at: address)
                            promise(.success(safeInfo))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
            }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }, receiveValue: { response in
                self.safe.update(from: response)
            })
            .store(in: &subscribers)
    }
}

extension Safe {

    func update(from safeInfo: SafeStatusRequest.Response) {
        objectWillChange.send()
        threshold = safeInfo.threshold.value
        owners = safeInfo.owners.map { $0.address }
        masterCopy = safeInfo.masterCopy.address
        version = safeInfo.version
        nonce = safeInfo.nonce.value
        modules = safeInfo.modules.map { $0.address }
        fallbackHandler = safeInfo.fallbackHandler.address
    }

}