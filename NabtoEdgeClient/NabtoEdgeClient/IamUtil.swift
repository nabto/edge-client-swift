//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import CBORCoding

/**
 * This class simplifies interaction with the Nabto Edge Embedded SDK device's CoAP IAM endpoints.
 *
 * For instance, it is made simple to invoke the different pairing endpoints - just invoke a simple high level
 * pairing function to pair the client with the connected device and don't worry about CBOR encoding and decoding.
 *
 * Read more about the important concept of pairing here: https://docs.nabto.com/developer/guides/concepts/iam/pairing.html
 *
 * All the most popular IAM device endpoints are wrapped to also allow management of the user profile on the device
 * (own or other users' if client is in admin role).
 *
 * Note that the device's IAM configuration must allow invocation of the different functions and the pairing modes must
 * be enabled at runtime. Read more about that in the general IAM intro here: https://docs.nabto.com/developer/guides/concepts/iam/intro.html
 */
class IamUtil {

    /**
     * Perform Local Open pairing, requesting the specified username.
     *
     * Local open pairing uses the trusted local network (LAN) pairing mechanism. No password is required for pairing and no
     * invitation is needed, anybody on the LAN can initiate pairing.
     *
     * Read more here: https://docs.nabto.com/developer/guides/concepts/iam/pairing.html#open-local
     *
     * @param connection An established connection to the device this client should be paired with
     * @param desiredUsername Assign this username on the device if available (pairing fails with .USERNAME_EXISTS if not)
     *
     * @throws USERNAME_EXISTS if desiredUsername is already in use on the device
     * @throws INVALID_INPUT if desiredUsername is not valid as per https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html#request
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not support local open pairing (the `IAM:PairingLocalOpen` action
     * is not set for the Unpaired role or the device does not support the pairing mode at all)
     * @throws PAIRING_MODE_DISABLED if the pairing mode is configured on the device but is disabled at runtime
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
        try PairLocalOpen(connection, desiredUsername).execute()
    }

    /**
     * Perform Local Open pairing asynchronously, requesting the specified username.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `pairLocalOpen()` function for details about possible error codes.
     *
     * @param connection An established connection to the device this client should be paired with
     * @param desiredUsername Assign this username on the device if available (pairing fails with .USERNAME_EXISTS if not)
     * @param closure Invoked when the pairing attempt succeeds or fails.
     */
    static public func pairLocalOpenAsync(
            connection: Connection,
            desiredUsername: String,
            closure: @escaping AsyncIamResultReceiver) throws {
        try PairLocalOpen(connection, desiredUsername).executeAsync(closure)
    }

    /**
     * Perform Local Initial pairing, assigning the default initial username configured on the device (typically "admin").
     *
     * In this mode, the initial user can be paired on the local network without providing a username or password - and
     * only the initial user. This is a typical bootstrap scenario to pair the admin user (device owner).
     *
     * Read more here: https://docs.nabto.com/developer/guides/concepts/iam/pairing.html#initial-local
     *
     * @param connection An established connection to the device this client should be paired with
     *
     * @throws INITIAL_USER_ALREADY_PAIRED if the initial user was already paired
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not support local open pairing (the `IAM:PairingLocalInitial` action
     * is not set for the Unpaired role or the device does not support the pairing mode at all)
     * @throws PAIRING_MODE_DISABLED if the pairing mode is configured on the device but is disabled at runtime.
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func pairLocalInitial(connection: Connection) throws {
        try PairLocalInitial(connection).execute()
    }

    /**
     * Perform Local Initial pairing asynchronously.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `pairLocalInitial()` function for details about possible error codes.
     *
     * @param connection An established connection to the device this client should be paired with
     * @param closure Invoked when the connect attempt succeeds or fails.
     */
    static public func pairLocalInitialAsync(connection: Connection, closure: @escaping AsyncIamResultReceiver) {
        PairLocalInitial(connection).executeAsync(closure)
    }

    /**
     * Perform Password Open pairing, requesting the specified username and authenticating using the specified password.
     *
     * In this mode a device has set a password which can be used in the pairing process to grant a client access to the
     * device. The client can pair remotely to the device if necessary; it is not necessary to be on the same LAN.
     *
     * Read more here: https://docs.nabto.com/developer/guides/concepts/iam/pairing.html#open-password
     *
     * @param connection An established connection to the device this client should be paired with
     * @param desiredUsername Assign this username on the device if available (pairing fails with .USERNAME_EXISTS if not)
     * @param password the common (not user-specific) password to allow pairing using Password Open pairing
     *
     * @throws USERNAME_EXISTS if desiredUsername is already in use on the device
     * @throws AUTHENTICATION_ERROR if the open pairing password was invalid for the device
     * @throws INVALID_INPUT if desiredUsername is not valid as per https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html#request
     * @throws INITIAL_USER_ALREADY_PAIRED if the initial user was already paired
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not support local open pairing (the `IAM:PairingPasswordOpen` action
     * is not set for the Unpaired role or the device does not support the pairing mode at all)
     * @throws PAIRING_MODE_DISABLED if the pairing mode is configured on the device but is disabled at runtime
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func pairPasswordOpen(connection: Connection, desiredUsername: String, password: String) throws {
        try PairPasswordOpen(connection: connection, desiredUsername: desiredUsername, password: password)
                .execute()
    }

    /**
     * Perform Password Open pairing asynchronously.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `pairPasswordOpen()` function for details about possible error codes.
     *
     * @param connection An established connection to the device this client should be paired with
     * @param desiredUsername Assign this username on the device if available (pairing fails with .USERNAME_EXISTS if not)
     * @param password the common (not user-specific) password to allow pairing using Password Open pairing
     * @param closure Invoked when the pairing attempt succeeds or fails.
     */
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

    /**
     * Perform Password Invite pairing, authenticating with the specified username and password.
     *
     * In the Password invite pairing mode a user is required in the system to be able to pair: An existing user (or
     * the system autonomously) creates a username and password that is somehow passed to the new user (an invitation).
     *
     * Read more here: https://docs.nabto.com/developer/guides/concepts/iam/pairing.html#invite
     *
     * @param connection An established connection to the device this client should be paired with
     * @param username Username for the invited user
     * @param password Password for the invited user
     *
     * @throws AUTHENTICATION_ERROR if authentication failed using the specified username/password combination for the device
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not support local open pairing (the `IAM:PairingPasswordInvite` action
     * is not set for the Unpaired role or the device does not support the pairing mode at all)
     * @throws PAIRING_MODE_DISABLED if the pairing mode is configured on the device but is disabled at runtime
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func pairPasswordInvite(connection: Connection, username: String, password: String) throws {
        try PairPasswordInvite(
                connection: connection,
                username: username,
                password: password).execute()
    }

    /**
     * Perform Password Invite pairing asynchronously.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `pairPasswordInvite()` function for details about possible error codes.
     *
     * @param connection An established connection to the device this client should be paired with
     * @param username Username for the invited user
     * @param password Password for the invited user
     * @param closure Invoked when the pairing attempt succeeds or fails.
     */
    static public func pairPasswordInviteAsync(connection: Connection,
                                               username: String,
                                               password: String,
                                               closure: @escaping AsyncIamResultReceiver) throws {
        try PairPasswordInvite(
                connection: connection,
                username: username,
                password: password).executeAsync(closure)
    }

    /**
     * Retrieve a list of the available pairing modes on the device.
     *
     * @param connection An established connection to the device
     *
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow retrieving this list (the
     * `IAM:GetPairing` action is not set for the Unpaired role)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        return try GetAvailablePairingModes(connection).execute()
    }

    /**
     * Retrieve a list of the available pairing modes on the device asynchronously.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK and resulting data upon successful
     * completion or with an error if an error occurs. See the `getAvailablePairingModes()` function for details about
     * possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the list of available pairing modes is successfully retrieved or retrieval fails.
     */
    static public func getAvailablePairingModesAsync(connection: Connection,
                                                     closure: @escaping AsyncIamResultReceiverWithData<[PairingMode]>) {
        return GetAvailablePairingModes(connection).executeAsyncWithData(closure)
    }

    /**
     * Retrieve device information that typically does not need a paired user.
     *
     * @param connection An established connection to the device
     *
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow retrieving this list (the
     * `IAM:GetPairing` action is not set for the Unpaired role)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func getDeviceDetails(connection: Connection) throws -> DeviceDetails {
        return try GetDeviceDetails(connection).execute()
    }

    /**
     * Asynchronously retrieve device information that typically does not need a paired user.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK and resulting data upon successful
     * completion or with an error if an error occurs. See the `getDeviceDetails()` function for details about
     * possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the device information is successfully retrieved or retrieval fails.
     */
    static public func getDeviceDetailsAsync(connection: Connection,
                                             closure: @escaping (IamError, DeviceDetails?) -> ()) {
        GetDeviceDetails(connection).executeAsyncWithData(closure)
    }

    /**
     * Query if the current user is paired or not on a specific device.
     *
     * Note that a negative answer could also indicate that the device does not support Nabto Edge IAM at all, so
     * to be able to interpret the result correctly, this must be known to be the case or not.
     *
     * @param connection An established connection to the device
     *
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func isCurrentUserPaired(connection: Connection) throws -> Bool {
        return try IsCurrentUserPaired(connection).execute()
    }

    /**
     * Query asynchronously if the current user is paired or not on a specific device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK and a boolean query result upon
     * successful completion or with an error if an error occurs. See the `isCurrentUserPaired()` function for
     * details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the device information is successfully retrieved or retrieval fails.
     */
    static public func isCurrentUserPairedAsync(connection: Connection,
                                                closure: @escaping AsyncIamResultReceiverWithData<Bool>) {
        IsCurrentUserPaired(connection).executeAsyncWithData(closure)
    }

    /**
     * Get details about a specific user on specific device.
     *
     * @param connection An established connection to the device
     *
     * @throws USER_DOES_NOT_EXIST if the user does not exist on the device
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow retrieving this user  (the
     * `IAM:GetUser` action is not set for the requesting role)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
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


