//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class GetDeviceDetails : AbstractIamInvocationProtocol {
    private(set) var method: String = "GET"
    private(set) var path: String = "/iam/pairing"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil
    private(set) var asyncHookAfterCoap: AsyncHook? = nil

    private(set) var hookAfterCoap: SyncHookWithResult?

    var payload: Data?

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 205: return IamError.OK
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        default:  return IamError.FAILED
        }
    }

    func getResult() throws -> DeviceDetails {
        if let payload = self.payload {
            return try DeviceDetails.decode(cbor: payload)
        } else {
            throw IamError.INVALID_RESPONSE(error: "empty")
        }
    }

    init(_ connection: Connection) {
        self.connection = connection
        self.hookAfterCoap = { response in
            self.payload = response.payload
        }
    }
}
