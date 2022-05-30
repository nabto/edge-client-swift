import Foundation

internal class CreateUser : AbstractIamInvocationTemplate {
    private(set) var method: String = "POST"
    private(set) var path: String = "/iam/users"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 201: return IamError.OK
        case 400: return IamError.INVALID_INPUT
        case 403: return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 409: return IamError.USERNAME_EXISTS
        default: return IamError.FAILED
        }
    }

    func mapResponse(_ response: CoapResponse) throws -> () {
        return
    }

    init(_ connection: Connection, _ cbor: Data) {
        self.connection = connection
        self.cbor = cbor
    }
}