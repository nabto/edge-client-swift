//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairingHelper {
    static internal func throwPairingError(_ error: Error) throws {
        if let pairingError = error as? PairingError {
            throw pairingError
        } else if let apiError = error as? NabtoEdgeClientError {
            throw PairingError.API_ERROR(cause: apiError)
        }
        throw PairingError.FAILED
    }

    static internal func invokePairingErrorHandler(_ error: Error, _ closure: @escaping AsyncPairingResultReceiver) {
        if let pairingError = error as? PairingError {
            closure(pairingError)
        } else if let apiError = error as? NabtoEdgeClientError {
            closure(PairingError.API_ERROR(cause: apiError))
        }
        closure(PairingError.FAILED)
    }

    // XXX move out?
    static internal func invokePasswordBasedPairing(connection: Connection,
                                                   path: String,
                                                   username: String,
                                                   password: String,
                                                   data: Data? = nil) throws {
        do {
            try connection.passwordAuthenticate(username: username, password: password)
            let coap = try connection.createCoapRequest(method: "POST", path: path)
            if let data = data {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: data)
            }
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 401: throw PairingError.FAILED                // never here
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw PairingError.PAIRING_MODE_DISABLED // never here - authentication error above if not enabled
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            if let pairingError = error as? PairingError {
                throw pairingError
            } else if let apiError = error as? NabtoEdgeClientError {
                if (apiError == .UNAUTHORIZED) {
                    throw PairingError.AUTHENTICATION_ERROR
                } else {
                    throw PairingError.API_ERROR(cause: apiError)
                }
            } else {
                throw PairingError.FAILED
            }
        }
    }

}