//
// Created by Ulrik Gammelby on 18/05/2022.
//

import Foundation

internal class GetAvailablePairingModes : AbstractIamInvocationTemplate {
    private(set) var method: String = "GET"
    private(set) var path: String = "/iam/pairing"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    private let cmdGetDeviceDetails: GetDeviceDetails

    func mapStatus(status: UInt16?) -> IamError {
        return cmdGetDeviceDetails.mapStatus(status: status)
    }

    func mapResponse(_ response: CoapResponse) throws -> [PairingMode] {
        if let payload = response.payload {
            let details = try DeviceDetails.decode(cbor: payload)
            return try details.Modes.map { s -> PairingMode in
                switch s {
                case "LocalInitial": return .LocalInitial
                case "LocalOpen": return .LocalOpen
                case "PasswordInvite": return .PasswordInvite
                case "PasswordOpen": return .PasswordOpen
                default: throw IamError.INVALID_RESPONSE(error: "pairing mode '\(s)'")
                }
            }
        } else {
            throw IamError.INVALID_RESPONSE(error: "\(path) returned empty response")
        }
    }

    init(_ connection: Connection) {
        self.cmdGetDeviceDetails = GetDeviceDetails(connection)
        self.connection = connection
    }
}
