//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import CBORCoding

public enum IamError: Error, Equatable {
    case OK
    case INVALID_INPUT
    case USERNAME_EXISTS
    case USER_DOES_NOT_EXIST
    case USER_IS_NOT_PAIRED
    case INITIAL_USER_ALREADY_PAIRED
    case ROLE_DOES_NOT_EXIST
    case AUTHENTICATION_ERROR
    case TOO_MANY_WRONG_PASSWORD_ATTEMPTS
    case PAIRING_MODE_DISABLED
    case BLOCKED_BY_DEVICE_CONFIGURATION
    case INVALID_RESPONSE(error: String)
    case INVALID_PAIRING_STRING(error: String)
    case API_ERROR(cause: NabtoEdgeClientError)
    case FAILED
}

public enum PairingMode {
    case LocalOpen
    case LocalInitial
    case PasswordOpen
    case PasswordInvite
}

public typealias AsyncPairingResultReceiver = (IamError) -> Void
public typealias AsyncPairingResultReceiverWithConnection = (IamError, Connection?) -> Void

// upper camelcase field names breaks standard Swift style - they match
// the key names in the CBOR string map for the "CoAP GET /iam/me" service
// https://docs.nabto.com/developer/api-reference/coap/iam/me.html
public struct IamUser: Codable {
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

    static func decode(cbor: Data) throws -> IamUser {
        let decoder = CBORDecoder()
        do {
            return try decoder.decode(IamUser.self, from: cbor)
        } catch {
            throw IamError.INVALID_RESPONSE(error: "\(error)")
        }
    }

    func encode() throws -> Data {
        let encoder = CBOREncoder()
        do {
            return try encoder.encode(self)
        } catch {
            throw IamError.INVALID_INPUT
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
            throw IamError.INVALID_RESPONSE(error: "\(error)")
        }
    }

    func encode() throws -> Data {
        let encoder = CBOREncoder()
        do {
            return try encoder.encode(self)
        } catch {
            throw IamError.INVALID_INPUT
        }
    }
}

class IamUtil {

    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
        try PairLocalOpen(connection, desiredUsername).execute()
    }

    static public func pairLocalOpenAsync(
            connection: Connection,
            desiredUsername: String,
            closure: @escaping AsyncPairingResultReceiver) throws {
        try PairLocalOpen(connection, desiredUsername).executeAsync(closure)
    }

    static public func pairLocalInitial(connection: Connection) throws {
        try PairLocalInitial(connection).execute()
    }

    static public func pairLocalInitialAsync(connection: Connection, closure: @escaping AsyncPairingResultReceiver) {
        PairLocalInitial(connection).executeAsync(closure)
    }

    static public func pairPasswordOpen(connection: Connection, desiredUsername: String, password: String) throws {
        try PairPasswordOpen(connection: connection, desiredUsername: desiredUsername, password: password)
                .execute()
    }

    static public func pairPasswordOpenAsync(
            connection: Connection,
            desiredUsername: String,
            password: String,
            closure: @escaping AsyncPairingResultReceiver) throws {
        try PairPasswordOpen(
                connection: connection,
                desiredUsername: desiredUsername,
                password: password).executeAsync(closure)
    }

    static public func pairPasswordInvite(connection: Connection, username: String, password: String) throws {
        try PairPasswordInvite(
                connection: connection,
                username: username,
                password: password).execute()
    }

    static public func pairPasswordInviteAsync(connection: Connection,
                                               username: String,
                                               password: String,
                                               closure: @escaping AsyncPairingResultReceiver) throws {
        try PairPasswordInvite(
                connection: connection,
                username: username,
                password: password).executeAsync(closure)
    }

    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        let details = try getDeviceDetails(connection: connection)
        return try details.Modes.map { s -> PairingMode in
            switch s {
            case "LocalInitial": return .LocalInitial
            case "LocalOpen": return .LocalOpen
            case "PasswordInvite": return .PasswordInvite
            case "PasswordOpen": return .PasswordOpen
            default: throw IamError.INVALID_RESPONSE(error: "pairing mode '\(s)'")
            }
        }
    }

    static public func getDeviceDetails(connection: Connection) throws -> DeviceDetails {
        let cmd = try GetDeviceDetails(connection)
        try cmd.execute()
        return try cmd.getResult()
    }

    static public func isCurrentUserPaired(connection: Connection) throws -> Bool {
        do {
            _ = try self.getCurrentUser(connection: connection)
        } catch {
            if let pairingError = error as? IamError {
                if (pairingError == .USER_IS_NOT_PAIRED) {
                    return false
                }
            }
            try rethrowPairingError(error)
        }
        return true
    }

    static public func getUser(connection: Connection, username: String) throws -> IamUser {
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/users/\(username)")
            let response = try coap.execute()
            switch (response.status) {
            case 205: break
            case 403: throw IamError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw IamError.USER_DOES_NOT_EXIST
            default: throw IamError.FAILED
            }
            return try IamUser.decode(cbor: response.payload)
        } catch {
            try rethrowPairingError(error)
            return IamUser(username: "swift 5.6 compiler error about missing return if not including this line")
        }
    }

    static public func getCurrentUser(connection: Connection) throws -> IamUser {
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/me")
            let response = try coap.execute()
            switch (response.status) {
            case 205: break
            case 404: throw IamError.USER_IS_NOT_PAIRED
            default: throw IamError.FAILED
            }
            return try IamUser.decode(cbor: response.payload)
        } catch {
            try rethrowPairingError(error)
            return IamUser(username: "swift 5.6 compiler error about missing return if not including this line")
        }
    }

    static public func deleteUser(connection: Connection, username: String) throws {
        do {
            let coap = try connection.createCoapRequest(method: "DELETE", path: "/iam/users/\(username)")
            let response = try coap.execute()
            switch (response.status) {
            case 202: break
            case 403: throw IamError.BLOCKED_BY_DEVICE_CONFIGURATION
            default: throw IamError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    static public func createNewUserForInvitePairing(connection: Connection,
                                                     username: String,
                                                     password: String,
                                                     role: String) throws {
        let user: IamUser
        let cborRequest = try IamUser(username: username).encode()
        do {
            // https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/users")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cborRequest)
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw IamError.INVALID_INPUT
            case 403: throw IamError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 409: throw IamError.USERNAME_EXISTS
            default: throw IamError.FAILED
            }
            user = try IamUser.decode(cbor: response.payload)
            if (user.Sct == nil) {
                throw IamError.INVALID_RESPONSE(error: "missing sct")
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
                value: password)
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
                fourOhFourMapping: IamError.ROLE_DOES_NOT_EXIST)
    }

    static public func updateUserSetDisplayName(connection: Connection,
                                         username: String,
                                         displayName: String) throws{
        try updateUser(
                connection: connection,
                username: username,
                parameter: "display-name",
                value: displayName)
    }

    static public func renameUser(connection: Connection,
                                  username: String,
                                  newUsername: String) throws {
        try updateUser(
                connection: connection,
                username: username,
                parameter: "username",
                value: newUsername)
    }

    static private func updateUser(connection: Connection,
                                   username: String,
                                   parameter: String,
                                   value: String,
                                   fourOhFourMapping: IamError=IamError.USER_DOES_NOT_EXIST) throws {
        let encoder = CBOREncoder()
        let cborRequest: Data = try encoder.encode(value)
        do {
            let coap = try connection.createCoapRequest(method: "PUT", path: "/iam/users/\(username)/\(parameter)")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cborRequest)
            let response = try coap.execute()
            switch (response.status) {
            case 204: break
            case 400: throw IamError.INVALID_INPUT
            case 403: throw IamError.BLOCKED_BY_DEVICE_CONFIGURATION
            case 404: throw fourOhFourMapping
            default: throw IamError.FAILED
            }
        } catch {
            try rethrowPairingError(error)
        }
    }

    static private func rethrowPairingError(_ error: Error) throws {
        if let pairingError = error as? IamError {
            throw pairingError
        } else if let apiError = error as? NabtoEdgeClientError {
            throw IamError.API_ERROR(cause: apiError)
        }
        throw IamError.FAILED
    }

    static private func invokePairingErrorHandler(_ error: Error, _ closure: @escaping AsyncPairingResultReceiver) {
        if let pairingError = error as? IamError {
            closure(pairingError)
        } else if let apiError = error as? NabtoEdgeClientError {
            closure(IamError.API_ERROR(cause: apiError))
        }
        closure(IamError.FAILED)
    }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// experimental functions - subject to change!

extension IamUtil {
    static public func pairAutomatic(client: Client,
                                     opts: ConnectionOptions,
                                     pairingString: String?=nil,
                                     desiredUsername: String?=nil) throws -> Connection {
        try PairAutomatic(
                client: client,
                opts: opts,
                pairingString: pairingString,
                desiredUsername: desiredUsername).execute()
    }

    static public func pairAutomaticAsync(client: Client,
                                          opts: ConnectionOptions,
                                          pairingString: String?=nil,
                                          desiredUsername: String?=nil,
                                          closure: @escaping AsyncPairingResultReceiverWithConnection) {
        PairAutomatic(
                client: client,
                opts: opts,
                pairingString: pairingString,
                desiredUsername: desiredUsername).executeAsync(closure)
    }
}
