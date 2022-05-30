import Foundation

internal class IsCurrentUserPaired : AbstractIamInvocationTemplate {
    private(set) var method: String = "GET"
    private(set) var path: String = "/iam/me"
    private(set) var connection: Connection
    private(set) var cbor: Data? = nil
    private(set) var hookBeforeCoap: SyncHook? = nil
    private(set) var asyncHookBeforeCoap: AsyncHook? = nil

    var result: Bool?

    func mapStatus(status: UInt16?) -> IamError {
        guard let status = status else {
            return IamError.FAILED
        }
        switch (status) {
        case 403:
            return IamError.BLOCKED_BY_DEVICE_CONFIGURATION
        case 205:
            self.result = true
            return IamError.OK
        case 404:
            self.result = false
            return IamError.OK
        default:
            return IamError.FAILED
        }
    }

    func mapResponse(_ response: CoapResponse) throws -> Bool {
        if let res = self.result {
            return res
        } else {
            throw IamError.INVALID_RESPONSE(error: "\(path) returned invalid response")
        }
    }

    init(_ connection: Connection) {
        self.connection = connection
    }
}