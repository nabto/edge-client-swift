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

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 205: return IamError.OK
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return IamError.IAM_NOT_SUPPORTED
        default:  return IamError.FAILED
        }
    }

    func mapResponse(_ response: CoapResponse) throws -> DeviceDetails {
        if let payload = response.payload {
            return try DeviceDetails.decode(cbor: payload)
        } else {
            throw IamError.INVALID_RESPONSE(error: "\(path) returned empty response")
        }
    }

    init(_ connection: Connection) {
        self.connection = connection
    }
}
