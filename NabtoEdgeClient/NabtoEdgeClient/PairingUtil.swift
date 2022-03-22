//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import CBORCoding

public enum PairingError: Error, Equatable {
    case INVALID_INPUT
    case USERNAME_EXISTS
    case USER_DOES_NOT_EXIST
    case ROLE_DOES_NOT_EXIST
    case AUTHENTICATION_ERROR
    case LOCAL_PAIRING_ATTEMPTED_REMOTE
    case PAIRING_MODE_DISABLED
    case BLOCKED_BY_DEVICE_CONFIGURATION
    case INVALID_RESPONSE(error: String)
    case API_ERROR(cause: NabtoEdgeClientError)
    case FAILED
}

class PairingUtil {

    // upper camelcase field names breaks standard Swift style - they match
    // the key names in the CBOR string map for the "CoAP GET /iam/me" service
    // https://docs.nabto.com/developer/api-reference/coap/iam/me.html
    public struct User: Codable {
        let Username: String
        let DisplayName: String?
        let Fingerprint: String?
        let Sct: String?
        let Role: String?

        init(username: String, displayName: String?=nil, fingerprint: String?=nil, sct: String?=nil, role: String?=nil) {
            self.Username = username
            self.DisplayName = displayName
            self.Fingerprint = fingerprint
            self.Sct = sct
            self.Role = role
        }

        static func decode(cbor: Data) throws -> User {
            let decoder = CBORDecoder()
            do {
                return try decoder.decode(User.self, from: cbor)
            } catch {
                throw PairingError.INVALID_RESPONSE(error: "\(error)")
            }
        }

        func encode() throws -> Data {
            let encoder = CBOREncoder()
            do {
                return try encoder.encode(self)
            } catch {
                throw PairingError.INVALID_INPUT
            }
        }

        public func cborAsHex() -> String? {
            let encoder = CBOREncoder()
            return try? encoder.encode(self).map { String(format: "%02hhx", $0) }.joined()
        }

    }

    public enum PairingMode {
        case LocalOpen
        case LocalInitial
        case PasswordOpen
        case PasswordInvite
    }

    static public func pair(connection: Connection, usingPairingString: String) {
        // todo parse string and invoke appropriate pairing function
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-local-open.html
    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
//        201: Pairing completed successfully.
//        201: Already paired.
//        400: Bad request (likely invalid username).
//        403: Blocked by IAM configuration.
//        404: Pairing mode disabled.
//        409: Username exists.
        let cbor = try User(username: desiredUsername).encode()
        do {
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/local-open")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            let response = try! coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            if let pairingError = error as? PairingError {
                throw pairingError
            } else if let apiError = error as? NabtoEdgeClientError {
                throw PairingError.API_ERROR(cause: apiError)
            } else {
                throw PairingError.FAILED
            }
        }
    }

    static public func pairLocalInitial(connection: Connection) {
        // todo invoke CoAP POST /iam/pairing/local-initial
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-password-open.html
    static public func pairPasswordOpen(connection: Connection, desiredUsername: String, password: String) throws {
        let cbor = try User(username: desiredUsername).encode()
        try invokePasswordBasedPairing(
                connection: connection,
                path: "/iam/pairing/password-open",
                username: "",
                password: password,
                data: Data(cbor)
                )
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-password-invite.html
    static public func pairPasswordInvite(connection: Connection, username: String, password: String) throws {
        try invokePasswordBasedPairing(
                connection: connection,
                path: "/iam/pairing/password-invite",
                username: username,
                password: password)
    }

    static private func invokePasswordBasedPairing(connection: Connection,
                                                   path: String,
                                                   username: String,
                                                   password: String,
                                                   data: Data?=nil) throws {
        do {
            try connection.passwordAuthenticate(username: username, password: password)
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/password-open")
            if let data = data {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: data)
            }
            let response = try! coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 401: throw PairingError.FAILED                // never here
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED // never here
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            if let pairingError = error as? PairingError {
                throw pairingError
            } else if let apiError = error as? NabtoEdgeClientError {
                if (apiError == .UNAUTHORIZED) {
                    throw PairingError.AUTHENTICATION_ERROR
                } else {
                    throw PairingError.API_ERROR(cause: apiError)
                }
            } else {
                throw PairingError.FAILED
            }
        }
    }

    static public func isCurrentUserPaired(connection: Connection) throws -> Bool {
//        205: On success.
//        404: The client is not paired.
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/me")
            let response = try! coap.execute()
            return response.status == 205
        } catch {
            // todo
        }

        // todo CoAP GET /iam/me .status == 205 ?
        return false
    }

    static public func getCurrentUser(connection: Connection) throws -> User {
        // todo CoAP GET /iam/me
        return User(username: "foo")
    }

    static public func deleteUser(connection: Connection, username: String) throws {
        do {
            let coap = try connection.createCoapRequest(method: "DELETE", path: "/iam/users/\(username)")
            let response = try! coap.execute()
            switch (response.status) {
            case 202: break
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            default: throw PairingError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    static public func createNewUserForInvitePairing(connection: Connection,
                                                     username: String,
                                                     password: String,
                                                     role: String?=nil,
                                                     displayName: String?=nil) throws {
        let user: User
        let cborRequest = try User(username: username).encode()
        do {
            // https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/users")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cborRequest)
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
            user = try User.decode(cbor: response.payload)
            if (user.Sct == nil) {
                throw PairingError.INVALID_RESPONSE(error: "missing sct")
            }
        } catch {
            try rethrowPairingError(error)
        }

        // if the following fails, a zombie user now exists on device - TODO, document how to check and cleanup!
        try updateUserSetPassword(
                connection: connection,
                username: username,
                password: password)
        if let role = role {
//            try updateUserSetRole(
//                    connection: connection,
//                    username: username,
//                    role: role)
        }
    }

    static func invokeCoap(connection: Connection, method: String, path: String, cborPayload: Data) throws {

    }

    static private func updateUserSetPassword(connection: Connection,
                                   username: String,
                                   password: String) throws{
        let encoder = CBOREncoder()
        let cborRequest: Data = try encoder.encode(password)
        do {
            let coap = try connection.createCoapRequest(method: "PUT", path: "/iam/users/\(username)/password")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cborRequest)
            let response = try coap.execute()
            switch (response.status) {
            case 204: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            default: throw PairingError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    static private func rethrowPairingError(_ error: Error) throws {
        if let pairingError = error as? PairingError {
            throw pairingError
        } else if let apiError = error as? NabtoEdgeClientError {
            throw PairingError.API_ERROR(cause: apiError)
        } else {
            throw PairingError.FAILED
        }
    }

    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        // todo CoAP GET /iam/pairing
        return []
    }

}
