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
        self.asyncHookBeforeCoap = { next in
            connection.passwordAuthenticateAsync(username: username, password: password, closure: next)
        }
    }

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 201: return IamError.OK
        case 400: return IamError.INVALID_INPUT
        case 401: return IamError.FAILED // never here
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return IamError.PAIRING_MODE_DISABLED // never here - authentication error before if not enabled
        case 409: return IamError.USERNAME_EXISTS
        default:  return IamError.FAILED
        }
    }
}
