//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairLocalInitial : PairAbstractProtocol {
    private(set) var method: String = "POST"
    private(set) var path: String = "/iam/pairing/local-initial"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil

    func mapStatus(status: UInt16?) -> PairingError {
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

    init(_ connection: Connection) {
        self.connection = connection
    }
}
