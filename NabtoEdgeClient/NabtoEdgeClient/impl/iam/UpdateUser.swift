import Foundation
import CBORCoding

internal class UpdateUser : AbstractIamInvocationTemplate {
    private(set) var method: String = "PUT"
    var path: String {
        return "/iam/users/\(username)/\(parameterName)"
    }
    private(set) var username: String
    private(set) var parameterName: String
    private(set) var fourOhFourMapping: IamError
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 204: return IamError.OK
        case 400: return IamError.INVALID_INPUT
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 404: return self.fourOhFourMapping
        default: return IamError.FAILED
        }
    }

    func mapResponse(_ response: CoapResponse) throws -> () {
        return
    }

    init(connection: Connection,
         username: String,
         parameterName: String,
         parameterValue: String,
         fourOhFourMapping: IamError=IamError.USER_DOES_NOT_EXIST
         ) throws {
        self.connection = connection
        self.username = username
        self.parameterName = parameterName
        self.fourOhFourMapping = fourOhFourMapping

        let encoder = CBOREncoder()
        self.cbor = try encoder.encode(parameterValue)
    }
}