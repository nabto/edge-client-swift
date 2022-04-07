//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairLocalOpen : PairAbstractProtocol {
    private(set) var method: String = "POST"
    private(set) var path: String = "/iam/pairing/local-open"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    func mapStatus(status: UInt16?) -> PairingError {
        guard let status = status else {
            return PairingError.FAILED
        }
        switch (status) {
        case 201: return PairingError.OK
        case 400: return PairingError.INVALID_INPUT
        case 403: return PairingError.PAIRING_MODE_DISABLED
        case 404: return PairingError.PAIRING_MODE_DISABLED
        case 409: return PairingError.USERNAME_EXISTS
        default:  return PairingError.FAILED
        }
    }

    init(_ connection: Connection, _ desiredUsername: String) throws {
        self.cbor = try PairingUser(username: desiredUsername).encode()
        self.connection = connection
    }
}
