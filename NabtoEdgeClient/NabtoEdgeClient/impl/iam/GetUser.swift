import Foundation

internal class GetUser : AbstractIamInvocationTemplate {
    private(set) var method: String = "GET"
    var path: String {
        return "/iam/users/" + username
    }
    private(set) var username: String
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
        case 404: return IamError.USER_DOES_NOT_EXIST
        default: return IamError.FAILED
        }
    }

    func mapResponse(_ response: CoapResponse) throws -> IamUser {
        if let payload = response.payload {
            return try IamUser.decode(cbor: response.payload)
        } else {
            throw IamError.INVALID_RESPONSE(error: "\(path) returned empty response")
        }
    }

    init(_ connection: Connection, _ username: String) {
        self.connection = connection
        self.username = username
    }
}