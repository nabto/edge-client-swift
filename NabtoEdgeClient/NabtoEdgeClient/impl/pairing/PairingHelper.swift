//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairingHelper {

    static internal func mapApiError(_ error: NabtoEdgeClientError) -> PairingError {
        switch (error) {
        case NabtoEdgeClientError.UNAUTHORIZED: return PairingError.AUTHENTICATION_ERROR
        case NabtoEdgeClientError.TOO_MANY_WRONG_PASSWORD_ATTEMPTS: return PairingError.TOO_MANY_WRONG_PASSWORD_ATTEMPTS
        default: return PairingError.API_ERROR(cause: error)
        }
    }

    static internal func throwPairingError(_ error: Error) throws {
        if let pairingError = error as? PairingError {
            throw pairingError
        } else if let apiError = error as? NabtoEdgeClientError {
            throw mapApiError(apiError)
        }
        throw PairingError.FAILED
    }

    static internal func invokePairingErrorHandler(_ error: Error, _ closure: @escaping AsyncPairingResultReceiver) {
        if let pairingError = error as? PairingError {
            closure(pairingError)
        } else if let apiError = error as? NabtoEdgeClientError {
            closure(mapApiError(apiError))
        } else {
            closure(PairingError.FAILED)
        }
    }
}