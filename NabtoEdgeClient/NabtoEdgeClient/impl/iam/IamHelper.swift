//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairingHelper {

    static internal func mapApiError(_ error: NabtoEdgeClientError) -> IamError {
        switch (error) {
        case NabtoEdgeClientError.UNAUTHORIZED: return IamError.AUTHENTICATION_ERROR
        case NabtoEdgeClientError.TOO_MANY_WRONG_PASSWORD_ATTEMPTS: return IamError.TOO_MANY_WRONG_PASSWORD_ATTEMPTS
        default: return IamError.API_ERROR(cause: error)
        }
    }

    static internal func throwIamError(_ error: Error) throws {
        if let pairingError = error as? IamError {
            throw pairingError
        } else if let apiError = error as? NabtoEdgeClientError {
            throw mapApiError(apiError)
        }
        throw IamError.FAILED
    }

    static internal func invokeIamErrorHandler(_ error: Error, _ closure: @escaping AsyncPairingResultReceiver) {
        if let pairingError = error as? IamError {
            closure(pairingError)
        } else if let apiError = error as? NabtoEdgeClientError {
            closure(mapApiError(apiError))
        } else {
            closure(IamError.FAILED)
        }
    }
}