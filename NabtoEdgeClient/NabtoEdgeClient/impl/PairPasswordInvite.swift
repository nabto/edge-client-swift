//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairPasswordInvite : PairAbstractProtocol {

    private(set) var method: String = "POST"
    private(set) var path: String = "/iam/pairing/password-invite"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    init(connection: Connection, username: String, password: String) throws {
        self.connection = connection
        self.hookBeforeCoap = {
            try connection.passwordAuthenticate(username: username, password: password)
        }
        self.asyncHookBeforeCoap = { closure in
            connection.passwordAuthenticateAsync(username: username, password: password, closure: closure)
        }
    }

    func mapStatus(status: UInt16?) -> PairingError {
        guard let status = status else {
            return PairingError.FAILED
        }
        switch (status) {
        case 201: return PairingError.OK
        case 400: return PairingError.INVALID_INPUT
        case 401: return PairingError.FAILED // never here
        case 403: return PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return PairingError.PAIRING_MODE_DISABLED // never here - authentication error before if not enabled
        case 409: return PairingError.USERNAME_EXISTS
        default:  return PairingError.FAILED
        }
    }
}
