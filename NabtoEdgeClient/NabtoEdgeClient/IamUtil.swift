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
    case IAM_NOT_SUPPORTED
    case API_ERROR(cause: NabtoEdgeClientError)
    case FAILED
}

public enum PairingMode {
    case LocalOpen
    case LocalInitial
    case PasswordOpen
    case PasswordInvite
}

public typealias AsyncIamResultReceiver = (IamError) -> Void
public typealias AsyncIamResultReceiverWithData<T> = (IamError, T?) -> Void
public typealias AsyncIamPayloadReceiver<T> = (IamError, Data?) -> Void

class IamUtil {

    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
        try PairLocalOpen(connection, desiredUsername).execute()
    }

    static public func pairLocalOpenAsync(
            connection: Connection,
            desiredUsername: String,
            closure: @escaping AsyncIamResultReceiver) throws {
        try PairLocalOpen(connection, desiredUsername).executeAsync(closure)
    }

    static public func pairLocalInitial(connection: Connection) throws {
        try PairLocalInitial(connection).execute()
    }

    static public func pairLocalInitialAsync(connection: Connection, closure: @escaping AsyncIamResultReceiver) {
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
            closure: @escaping AsyncIamResultReceiver) throws {
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
                                               closure: @escaping AsyncIamResultReceiver) throws {
        try PairPasswordInvite(
                connection: connection,
                username: username,
                password: password).executeAsync(closure)
    }

    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        return try GetAvailablePairingModes(connection).execute()
    }

    static public func getAvailablePairingModesAsync(connection: Connection,
                                                     closure: @escaping AsyncIamResultReceiverWithData<[PairingMode]>) {
        return GetAvailablePairingModes(connection).executeAsyncWithData(closure)
    }

    static public func getDeviceDetails(connection: Connection) throws -> DeviceDetails {
        return try GetDeviceDetails(connection).execute()
    }

    static public func getDeviceDetailsAsync(connection: Connection,
                                             closure: @escaping (IamError, DeviceDetails?) -> ()) {
        GetDeviceDetails(connection).executeAsyncWithData(closure)
    }

    static public func isCurrentUserPaired(connection: Connection) throws -> Bool {
        return try IsCurrentUserPaired(connection).execute()
    }

    static public func isCurrentUserPairedAsync(connection: Connection,
                                                closure: @escaping AsyncIamResultReceiverWithData<Bool>) {
        IsCurrentUserPaired(connection).executeAsyncWithData(closure)
    }

    static public func getUser(connection: Connection, username: String) throws -> IamUser {
        try GetUser(connection, username).execute()
    }

    static public func getUserAsync(connection: Connection,
                                    username: String,
                                    closure: @escaping AsyncIamResultReceiverWithData<IamUser>) {
        GetUser(connection, username).executeAsyncWithData(closure)
    }

    static public func getCurrentUser(connection: Connection) throws -> IamUser {
        try GetCurrentUser(connection).execute()
    }

    static public func getCurrentUserAsync(connection: Connection,
                                           closure: @escaping AsyncIamResultReceiverWithData<IamUser>) {
        GetCurrentUser(connection).executeAsyncWithData(closure)
    }

    static public func deleteUser(connection: Connection, username: String) throws {
        try DeleteUser(connection, username).execute()
    }

    static public func deleteUserAsync(connection: Connection, username: String,
                                       closure: @escaping AsyncIamResultReceiver) throws {
        try DeleteUser(connection, username).executeAsync(closure)
    }

    static public func createUser(connection: Connection,
                                  username: String,
                                  password: String,
                                  role: String) throws {
        try CreateUser(connection, username).execute()
        // if the following fails, a zombie user now exists on device
        // TODO, document when it can occur (network error or race condition (user renamed before password/role set, quite unlikely))
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: password).execute()
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: role,
                fourOhFourMapping: IamError.ROLE_DOES_NOT_EXIST).execute()
    }

    static public func createUserAsync(connection: Connection,
                                       username: String,
                                       password: String,
                                       role: String,
                                       closure: @escaping AsyncIamResultReceiver) {
        do {
            try CreateUser(connection, username).executeAsync { error in
                if (error == IamError.OK) {
                    do {
                        // if the following fails, a zombie user now exists on device
                        // TODO, document when it can occur (network error or race condition (user renamed before password/role set, quite unlikely))
                        try UpdateUser(
                                connection: connection,
                                username: username,
                                parameterName: "password",
                                parameterValue: password).executeAsync { error in
                            if (error == IamError.OK) {
                                do {
                                    try UpdateUser(
                                            connection: connection,
                                            username: username,
                                            parameterName: "role",
                                            parameterValue: role,
                                            fourOhFourMapping: IamError.ROLE_DOES_NOT_EXIST).executeAsync { error in
                                        if (error == IamError.OK) {
                                            closure(IamError.OK)
                                        } else {
                                            // UpdateUser (role) failed
                                            IamHelper.invokeIamErrorHandler(error, closure)
                                        }
                                    }
                                } catch {
                                    // cbor encoding failed in ctor before async UpdateUser (role) invocation started
                                    IamHelper.invokeIamErrorHandler(error, closure)
                                }
                            } else {
                                // UpdateUser (password) failed
                                IamHelper.invokeIamErrorHandler(error, closure)
                            }
                        }
                    } catch {
                        // cbor encoding failed in ctor before async UpdateUser (password) invocation started
                        IamHelper.invokeIamErrorHandler(error, closure)
                    }
                } else {
                    IamHelper.invokeIamErrorHandler(error, closure)
                }
            }
        } catch {
            // cbor encoding failed in ctor before async CreateUser invocation started
            IamHelper.invokeIamErrorHandler(error, closure)
        }
    }


    static public func updateUserPassword(connection: Connection,
                                          username: String,
                                          password: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: password).execute()
    }

    static public func updateUserPasswordAsync(connection: Connection,
                                               username: String,
                                               password: String,
                                               closure: @escaping AsyncIamResultReceiver) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: password).executeAsync(closure)
    }

    static public func updateUserRole(connection: Connection,
                                      username: String,
                                      role: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: role,
                fourOhFourMapping: IamError.ROLE_DOES_NOT_EXIST
        ).execute()
    }

    static public func updateUserRoleAsync(connection: Connection,
                                           username: String,
                                           role: String,
                                           closure: @escaping AsyncIamResultReceiver) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: role,
                fourOhFourMapping: IamError.ROLE_DOES_NOT_EXIST
        ).executeAsync(closure)
    }

    static public func updateUserDisplayName(connection: Connection,
                                             username: String,
                                             displayName: String) throws{
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "display-name",
                parameterValue: displayName).execute()
    }

    static public func updateUserDisplayNameAsync(connection: Connection,
                                                  username: String,
                                                  displayName: String,
                                                  closure: @escaping AsyncIamResultReceiver) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "display-name",
                parameterValue: displayName).executeAsync(closure)
    }

    static public func renameUser(connection: Connection,
                                  username: String,
                                  newUsername: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "username",
                parameterValue: newUsername).execute()
    }

    static public func renameUserAsync(connection: Connection,
                                       username: String,
                                       newUsername: String,
                                       closure: @escaping AsyncIamResultReceiver) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "username",
                parameterValue: newUsername).executeAsync(closure)
    }

}

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


