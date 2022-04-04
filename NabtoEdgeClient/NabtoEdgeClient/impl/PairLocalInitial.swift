//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairLocalInitial {

    let connection: Connection
    let method = "POST"
    let path = "/iam/pairing/local-initial"

    init(_ connection: Connection) {
        self.connection = connection
    }

    internal func execute() throws {
        do {
            let coap = try createCoapRequest(connection: connection)
            let response = try coap.execute()
            let error = self.mapStatus(status: response.status)
            if (error != PairingError.OK) {
                throw error
            }
        } catch {
            try PairingHelper.rethrowPairingError(error)
        }
    }

    internal func executeAsync(_ connection: Connection, _ closure: @escaping AsyncPairingResultReceiver) {
        do {
            let coap = try createCoapRequest(connection: connection)
            coap.executeAsync { error, response in
                if (error != NabtoEdgeClientError.OK) {
                    PairingHelper.invokePairingErrorHandler(error, closure)
                } else {
                    closure(self.mapStatus(status: response?.status))
                }
            }
        } catch {
            PairingHelper.invokePairingErrorHandler(error, closure)
        }
    }

    private func createCoapRequest(connection: Connection) throws -> CoapRequest {
        return try connection.createCoapRequest(method: self.method, path: self.path)
    }

    private func mapStatus(status: UInt16?) -> PairingError {
        guard let status = status else {
            return PairingError.FAILED
        }
        switch (status) {
        case 201: return PairingError.OK
        case 403: return PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return PairingError.PAIRING_MODE_DISABLED
        case 409: return PairingError.INITIAL_USER_ALREADY_PAIRED
        default:  return PairingError.FAILED
        }
    }
}