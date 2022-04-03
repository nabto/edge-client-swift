//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import CBORCoding

public enum PairingError: Error, Equatable {
    case INVALID_INPUT
    case USERNAME_EXISTS
    case USER_DOES_NOT_EXIST
    case USER_IS_NOT_PAIRED
    case INITIAL_USER_ALREADY_PAIRED
    case ROLE_DOES_NOT_EXIST
    case AUTHENTICATION_ERROR
    case PAIRING_MODE_DISABLED
    case BLOCKED_BY_DEVICE_CONFIGURATION
    case INVALID_RESPONSE(error: String)
    case INVALID_PAIRING_STRING(error: String)
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

        init(username: String, displayName: String? = nil, fingerprint: String? = nil, sct: String? = nil, role: String? = nil) {
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
            return try? encoder.encode(self).map {
                        String(format: "%02hhx", $0)
                    }
                    .joined()
        }

    }

    // upper camelcase field names breaks standard Swift style - they match
    // the key names in the CBOR string map for the "CoAP GET /iam/pairing" service
    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing.html
    public struct DeviceDetails: Codable {
        let Modes: [String]
        let NabtoVersion: String
        let AppVersion: String?
        let AppName: String?
        let ProductId: String
        let DeviceId: String

        public init(Modes: [String], NabtoVersion: String, AppVersion: String, AppName: String, ProductId: String, DeviceId: String) {
            self.Modes = Modes
            self.NabtoVersion = NabtoVersion
            self.AppVersion = AppVersion
            self.AppName = AppName
            self.ProductId = ProductId
            self.DeviceId = DeviceId
        }

        static func decode(cbor: Data) throws -> DeviceDetails {
            let decoder = CBORDecoder()
            do {
                return try decoder.decode(DeviceDetails.self, from: cbor)
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

    }

    public enum PairingMode {
        case LocalOpen
        case LocalInitial
        case PasswordOpen
        case PasswordInvite
    }

    static public func pair(client: Client,
                            opts: ConnectionOptions,
                            pairingString: String?=nil,
                            desiredUsername: String?=nil) throws -> Connection {
        var password: String!
        if let pairingString = pairingString {
            let elements = pairingString.components(separatedBy: ",")
            for element in elements {
                let tuple = element.components(separatedBy: "=")
                let key = tuple[0]
                let value = tuple[1]
                switch (key) {
                case "p": opts.ProductId = value; break
                case "d": opts.DeviceId = value; break
                case "pwd": password = value; break
                case "sct": opts.ServerConnectToken = value; break
                default: throw PairingError.INVALID_PAIRING_STRING(error: "unexpected element \(key)")
                }
            }
            if (opts.ProductId == nil || opts.DeviceId == nil || password == nil || opts.ServerConnectToken == nil) {
                throw PairingError.INVALID_PAIRING_STRING(error: "missing element in pairing string")
            }
        }

        let connection = try client.createConnection()
        try connection.updateOptions(options: opts)
        try connection.connect()

        do {
            try pairLocalInitial(connection: connection)
        } catch {
            if let desiredUsername = desiredUsername {
                do {
                    try pairLocalOpen(connection: connection, desiredUsername: desiredUsername)
                } catch {
                    if let password = password {
                        try pairPasswordOpen(connection: connection, desiredUsername: desiredUsername, password: password)
                    }
                }
            }
        }

        return connection
    }

    static public func getDeviceDetails(connection: Connection) throws -> DeviceDetails {
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/pairing")
            let response = try coap.execute()
            switch (response.status) {
            case 205: break
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            default: throw PairingError.FAILED
            }
            return try DeviceDetails.decode(cbor: response.payload)
        } catch {
            try rethrowPairingError(error)
            // swift 5.6 compiler error about missing return. grmbl.
            return DeviceDetails(Modes: [], NabtoVersion: "", AppVersion: "", AppName: "", ProductId: "", DeviceId: "")
        }
    }

    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        let details = try getDeviceDetails(connection: connection)
        return try details.Modes.map { s -> PairingMode in
            switch s {
            case "LocalInitial": return .LocalInitial
            case "LocalOpen": return .LocalOpen
            case "PasswordInvite": return .PasswordInvite
            case "PasswordOpen": return .PasswordOpen
            default: throw PairingError.INVALID_RESPONSE(error: "pairing mode '\(s)'")
            }
        }
    }

    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
        let cbor = try User(username: desiredUsername).encode()
        do {
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/local-open")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    static public func pairLocalInitial(connection: Connection) throws {
        do {
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/local-initial")
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw PairingError.PAIRING_MODE_DISABLED
            case 409: throw PairingError.INITIAL_USER_ALREADY_PAIRED
            default: throw PairingError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-password-open.html
    static public func pairPasswordOpen(connection: Connection, desiredUsername: String, password: String) throws {
        let cbor = try User(username: desiredUsername).encode()
        try invokePasswordBasedPairing(
                connection: connection,
                path: "/iam/pairing/password-open",
                username: "",
                password: password,
                data: cbor
        )
    }

    /**
     * Perform Password Invite pairing.
     * @throws AUTHENTICATION_ERROR if not possible to authenticate using the specified username and password
     */
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
                                                   data: Data? = nil) throws {
        do {
            try connection.passwordAuthenticate(username: username, password: password)
            let coap = try connection.createCoapRequest(method: "POST", path: path)
            if let data = data {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: data)
            }
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 401: throw PairingError.FAILED                // never here
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw PairingError.PAIRING_MODE_DISABLED // never here - authentication error above if not enabled
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
        do {
            _ = try self.getCurrentUser(connection: connection)
        } catch {
            if let pairingError = error as? PairingError {
                if (pairingError == .USER_IS_NOT_PAIRED) {
                    return false
                }
            }
            try rethrowPairingError(error)
        }
        return true
    }

    static public func getUser(connection: Connection, username: String) throws -> User {
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/users/\(username)")
            let response = try coap.execute()
            switch (response.status) {
            case 205: break
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw PairingError.USER_DOES_NOT_EXIST
            default: throw PairingError.FAILED
            }
            return try User.decode(cbor: response.payload)
        } catch {
            try rethrowPairingError(error)
            return User(username: "swift 5.6 compiler error about missing return if not including this line")
        }
    }

    static public func getCurrentUser(connection: Connection) throws -> User {
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/me")
            let response = try coap.execute()
            switch (response.status) {
            case 205: break
            case 404: throw PairingError.USER_IS_NOT_PAIRED
            default: throw PairingError.FAILED
            }
            return try User.decode(cbor: response.payload)
        } catch {
            try rethrowPairingError(error)
            return User(username: "swift 5.6 compiler error about missing return if not including this line")
        }
    }

    static public func deleteUser(connection: Connection, username: String) throws {
        do {
            let coap = try connection.createCoapRequest(method: "DELETE", path: "/iam/users/\(username)")
            let response = try coap.execute()
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
                                                     role: String) throws {
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
        try updateUserSetRole(
                connection: connection,
                username: username,
                role: role)
    }


    static public func updateUserSetPassword(connection: Connection,
                                      username: String,
                                      password: String) throws {
        try updateUser(
                connection: connection,
                username: username,
                parameter: "password",
                value: password,
                fourOhFourMapping: PairingError.USER_DOES_NOT_EXIST
        )
    }

    static public func updateUserSetRole(connection: Connection,
                                         username: String,
                                         role: String) throws{
        try updateUser(
                connection: connection,
                username: username,
                parameter: "role",
                value: role,
                // user was just created - so ambiguous 404 is most likely due to missing role (... unless race condition)
                fourOhFourMapping: PairingError.ROLE_DOES_NOT_EXIST
        )
    }

    static public func updateUserSetDisplayName(connection: Connection,
                                         username: String,
                                         displayName: String) throws{
        try updateUser(
                connection: connection,
                username: username,
                parameter: "display-name",
                value: displayName,
                fourOhFourMapping: PairingError.USER_DOES_NOT_EXIST
        )
    }

    static public func renameUser(connection: Connection,
                                  username: String,
                                  newUsername: String) throws {
        try updateUser(
                connection: connection,
                username: username,
                parameter: "username",
                value: newUsername,
                // user was just created - so ambiguous 404 is most likely due to missing role (... unless race condition)
                fourOhFourMapping: PairingError.ROLE_DOES_NOT_EXIST
        )
    }

    static private func updateUser(connection: Connection,
                                   username: String,
                                   parameter: String,
                                   value: String,
                                   fourOhFourMapping: PairingError) throws {
        let encoder = CBOREncoder()
        let cborRequest: Data = try encoder.encode(value)
        do {
            let coap = try connection.createCoapRequest(method: "PUT", path: "/iam/users/\(username)/\(parameter)")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cborRequest)
            let response = try coap.execute()
            switch (response.status) {
            case 204: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw fourOhFourMapping
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
        }
        throw PairingError.FAILED
    }

}
