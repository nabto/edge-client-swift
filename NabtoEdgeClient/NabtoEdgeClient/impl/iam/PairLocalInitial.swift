//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairLocalInitial : AbstractIamInvocationTemplate {
    private(set) var method: String = "POST"
    private(set) var path: String = "/iam/pairing/local-initial"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil
    private(set) var hookAfterCoap: (() throws -> ())? = nil

    func mapResponse(_ response: CoapResponse) throws -> () {
        return
    }

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 201: return IamError.OK
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return IamError.PAIRING_MODE_DISABLED
        case 409: return IamError.INITIAL_USER_ALREADY_PAIRED
        default:  return IamError.FAILED
        }
    }

    init(_ connection: Connection) {
        self.connection = connection
    }
}
