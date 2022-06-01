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
public class IamUtil {

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
        let cbor = try IamUser(username: desiredUsername).encode()
        try PairLocalOpen(connection, cbor: cbor).execute()
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
            closure: @escaping AsyncIamResultReceiver) {
        let cbor: Data
        do {
            cbor = try IamUser(username: desiredUsername).encode()
        } catch {
            IamHelper.invokeIamErrorHandler(error, closure)
            return
        }
        PairLocalOpen(connection, cbor: cbor).executeAsync(closure)
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
        let cbor = try IamUser(username: desiredUsername).encode()
        try PairPasswordOpen(connection: connection, password: password, cbor: cbor).execute()
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
            closure: @escaping AsyncIamResultReceiver) {
        let cbor: Data
        do {
            cbor = try IamUser(username: desiredUsername).encode()
        } catch {
            IamHelper.invokeIamErrorHandler(error, closure)
            return
        }
        PairPasswordOpen(
                connection: connection,
                password: password,
                cbor: cbor).executeAsync(closure)
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
                                               closure: @escaping AsyncIamResultReceiver) {
        PairPasswordInvite(
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
     * @param connection An established connection to the device
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     * @return true iff the current user is paired with the device
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
     * @param closure Invoked when the pairing information is successfully retrieved or retrieval fails.
     */
    static public func isCurrentUserPairedAsync(connection: Connection,
                                                closure: @escaping AsyncIamResultReceiverWithData<Bool>) {
        IsCurrentUserPaired(connection).executeAsyncWithData(closure)
    }

    /**
     * Get details about a specific user.
     *
     * @param connection An established connection to the device
     *
     * @throws USER_DOES_NOT_EXIST if the user does not exist on the device
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow retrieving this user  (the
     * `IAM:GetUser` action is not set for the requesting role)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     * @return an IamUser instance describing the requested user
     */
    static public func getUser(connection: Connection, username: String) throws -> IamUser {
        try GetUser(connection, username).execute()
    }

    /**
     * Asynchronously get details about a specific user.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK and an IamUser object upon
     * successful completion or with an error if an error occurs. See the `getUser()` function for
     * details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the user information is successfully retrieved or retrieval fails.
     */
    static public func getUserAsync(connection: Connection,
                                    username: String,
                                    closure: @escaping AsyncIamResultReceiverWithData<IamUser>) {
        GetUser(connection, username).executeAsyncWithData(closure)
    }

    /**
     * Get details about the user that has opened the current connection to the device.
     *
     * @param connection An established connection to the device
     *
     * @throws USER_DOES_NOT_EXIST if the current user is not paired with the device.
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     * @return an IamUser instance describing the current user
     */
    static public func getCurrentUser(connection: Connection) throws -> IamUser {
        try GetCurrentUser(connection).execute()
    }

    /**
     * Asynchronously get details about a specific user.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK and an IamUser object upon
     * successful completion or with an error if an error occurs. See the `getCurrentUser()` function for
     * details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the user information is successfully retrieved or retrieval fails.
     */
    static public func getCurrentUserAsync(connection: Connection,
                                           closure: @escaping AsyncIamResultReceiverWithData<IamUser>) {
        GetCurrentUser(connection).executeAsyncWithData(closure)
    }

    /**
     * Create an IAM user on device.
     *
     * See https://docs.nabto.com/developer/guides/concepts/iam/intro.html for an intro to the concept of users and roles.
     *
     * @param connection An established connection to the device
     * @param username Username for the new user
     * @param password Password for the new user
     * @param role IAM role for the new user
     * @throws INVALID_INPUT if username is not valid as per https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html#request
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow the current user to create a new user (the
     * `IAM:CreateUser` action is not allowed for the requesting role)
     * @throws ROLE_DOES_NOT_EXIST the specified role does not exist in the device IAM configuration
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     * @return an IamUser instance describing the current user
     */
    static public func createUser(connection: Connection,
                                  username: String,
                                  password: String,
                                  role: String) throws {
        try CreateUser(connection, IamUser(username: username).encode()).execute()
        // if the following fails, a zombie user now exists on device
        // TODO, document when it can occur (network error or race condition (user renamed before password/role set, quite unlikely))
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: try toCbor(password)).execute()
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: try toCbor(role),
                status404ErrorCode: IamError.ROLE_DOES_NOT_EXIST).execute()
    }

    /**
     * Asynchronously create an IAM user on device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `createUser()` function for details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param username Username for the new user
     * @param password Password for the new user
     * @param role IAM role for the new user
     * @param closure Invoked when the user is created successfully or an error occurs
     */
    static public func createUserAsync(connection: Connection,
                                       username: String,
                                       password: String,
                                       role: String,
                                       closure: @escaping AsyncIamResultReceiver) {
        let user: Data
        let encodedPassword: Data
        let encodedRole: Data
        do {
            user = try IamUser(username: username).encode()
            encodedPassword = try toCbor(password)
            encodedRole = try toCbor(role)
        } catch {
            closure(IamError.FAILED)
            return
        }

        CreateUser(connection, user).executeAsync { error in
            guard error == IamError.OK else {
                IamHelper.invokeIamErrorHandler(error, closure)
                return
            }
            // if the following fails, a zombie user now exists on device
            // TODO, document when it can occur (network error or race condition (user renamed before password/role set, quite unlikely))
            UpdateUser(
                    connection: connection,
                    username: username,
                    parameterName: "password",
                    parameterValue: encodedPassword).executeAsync { error in
                guard error == IamError.OK else {
                    IamHelper.invokeIamErrorHandler(error, closure)
                    return
                }

                UpdateUser(
                        connection: connection,
                        username: username,
                        parameterName: "role",
                        parameterValue: encodedRole,
                        status404ErrorCode: IamError.ROLE_DOES_NOT_EXIST).executeAsync { error in
                    if (error == IamError.OK) {
                        closure(IamError.OK)
                    } else {
                        IamHelper.invokeIamErrorHandler(error, closure)
                    }
                }
            }
        }
    }

    /**
     * Update an IAM user's password on device.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have password updated
     * @param password New password for the user
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow the current user to update the specified user's password (the
     * `IAM:SetUserPassword` action is not allowed for the requesting role for the `IAM:Username` user)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func updateUserPassword(connection: Connection,
                                          username: String,
                                          password: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: try toCbor(password)).execute()
    }

    /**
     * Asynchronously update an IAM user's password on device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `updateUserPassword()` function for details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have password updated
     * @param password New password for the user
     * @param closure Invoked when the user is deleted or an error occurs
     */
    static public func updateUserPasswordAsync(connection: Connection,
                                               username: String,
                                               password: String,
                                               closure: @escaping AsyncIamResultReceiver) {
        guard let cbor = toCbor(password) else {
            closure(IamError.FAILED)
            return
        }
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "password",
                parameterValue: cbor).executeAsync(closure)
    }

    /**
     * Update an IAM user's role on device.
     *
     * Known issue: This function currently assumes the user exists. To be able to interpret the
     * ROLE_DOES_NOT_EXIST code correctly, this assumption most hold. Later it can gracefully handle
     * non-existing users
     *
     * See https://docs.nabto.com/developer/guides/concepts/iam/intro.html for an intro to the concept of roles.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have password updated
     * @param role New role for the user
     * @throws USER_DOES_NOT_EXIST if the specified user does not exist on the device (see note above)
     * @throws ROLE_DOES_NOT_EXIST the specified role does not exist in the device IAM configuration (see note above)
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow the current user to update the specified user's role (the
     * `IAM:SetUserRole` action is not allowed for the requesting role for the `IAM:Username` user)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func updateUserRole(connection: Connection,
                                      username: String,
                                      role: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: try toCbor(role),
                status404ErrorCode: IamError.ROLE_DOES_NOT_EXIST
        ).execute()
    }

    /**
     * Asynchronously update an IAM user's role on device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `updateUserRole()` function for details about possible error codes and known issues.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have password updated
     * @param role New role for the user
     * @param closure Invoked when the user is deleted or an error occurs
     */
    static public func updateUserRoleAsync(connection: Connection,
                                           username: String,
                                           role: String,
                                           closure: @escaping AsyncIamResultReceiver) {
        guard let cbor = toCbor(role) else {
            closure(IamError.FAILED)
            return
        }
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "role",
                parameterValue: cbor,
                status404ErrorCode: IamError.ROLE_DOES_NOT_EXIST
        ).executeAsync(closure)
    }

    /**
     * Update an IAM user's display name on device.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have display name updated
     * @param displayName New display name
     * @throws USER_DOES_NOT_EXIST if the specified user does not exist on the device (see note above)
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow the current user to update the specified user's display name (the
     * `IAM:SetUserDisplayName` action is not allowed for the requesting role for the `IAM:Username` user)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func updateUserDisplayName(connection: Connection,
                                             username: String,
                                             displayName: String) throws{
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "display-name",
                parameterValue: try toCbor(displayName)).execute()
    }

    /**
     * Asynchronously update an IAM user's display name on device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `updateUserDisplayName()` function for details about possible error codes and known issues.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have display name updated
     * @param displayName New display name
     * @param closure Invoked when the user is deleted or an error occurs
     */
    static public func updateUserDisplayNameAsync(connection: Connection,
                                                  username: String,
                                                  displayName: String,
                                                  closure: @escaping AsyncIamResultReceiver) {
        guard let cbor = toCbor(displayName) else {
            closure(IamError.FAILED)
            return
        }
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "display-name",
                parameterValue: cbor).executeAsync(closure)
    }

    /**
     * Update an IAM user's username on device.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have username updated
     * @param newUsername New username for the user
     * @throws USER_DOES_NOT_EXIST if the specified user does not exist on the device (see note above)
     * @throws INVALID_INPUT if username is not valid as per https://docs.nabto.com/developer/api-reference/coap/iam/post-users.html#request
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow the current user to update the specified user's display name (the
     * `IAM:SetUserUsername` action is not allowed for the requesting role for the `IAM:Username` user)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func renameUser(connection: Connection,
                                  username: String,
                                  newUsername: String) throws {
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "username",
                parameterValue: toCbor(newUsername)).execute()
    }

    /**
     * Asynchronously update an IAM user's username on device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `renameUser()` function for details about possible error codes and known issues.
     *
     * @param connection An established connection to the device
     * @param username Username for the user that should have username updated
     * @param newUsername New username for the user
     * @param closure Invoked when the user is deleted or an error occurs
     */
    static public func renameUserAsync(connection: Connection,
                                       username: String,
                                       newUsername: String,
                                       closure: @escaping AsyncIamResultReceiver) {
        guard let cbor = toCbor(newUsername) else {
            closure(IamError.FAILED)
            return
        }
        try UpdateUser(
                connection: connection,
                username: username,
                parameterName: "username",
                parameterValue: cbor).executeAsync(closure)
    }

    /**
     * Delete the specified user from device.
     *
     * @param connection An established connection to the device
     *
     * @throws USER_DOES_NOT_EXIST if the specified user does not exist on the device
     * @throws BLOCKED_BY_DEVICE_CONFIGURATION if the device configuration does not allow deleting this user (the
     * `IAM:DeleteUser` action for the `IAM:Username` attribute is not allowed for the requesting role)
     * @throws IAM_NOT_SUPPORTED if Nabto Edge IAM is not supported by the device
     */
    static public func deleteUser(connection: Connection, username: String) throws {
        try DeleteUser(connection, username).execute()
    }

    /**
     * Asynchronously delete the specified user from device.
     *
     * The specified AsyncIamResultReceiver closure is invoked with IamError.OK upon successful completion or with an
     * error if an error occurs. See the `deleteUser()` function for details about possible error codes.
     *
     * @param connection An established connection to the device
     * @param closure Invoked when the user is deleted or an error occurs
     */
    static public func deleteUserAsync(connection: Connection, username: String,
                                       closure: @escaping AsyncIamResultReceiver) {
        try DeleteUser(connection, username).executeAsync(closure)
    }

    static private func toCbor(_ value: String) throws -> Data {
        let encoder = CBOREncoder()
        do {
            return try encoder.encode(value)
        } catch {
            // not to be handled by user - encoding of string should not fail
            throw IamError.FAILED
        }
    }

    static private func toCbor(_ value: String) -> Data? {
        let encoder = CBOREncoder()
        return try? encoder.encode(value)
    }
}

public enum IamError: Error, Equatable {
    case OK
    case INVALID_INPUT
    case USERNAME_EXISTS
    case USER_DOES_NOT_EXIST
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

/**
 * This struct contains information about a user on a Nabto Edge Embedded device.
 *
 * Note that upper camelcase field names breaks standard Swift style - the field names match
 * the key names in the CBOR string map for the "CoAP GET /iam/users/:username" endpoint, see
 * https://docs.nabto.com/developer/api-reference/coap/iam/users-get-user.html
 */
public struct IamUser: Codable {
    /**
     * The username of this IAM user.
     */
    public let Username: String

    /**
     * The display name of this IAM user.
     */
    public let DisplayName: String?

    /**
     * The public key fingerprint of this IAM user.
     */
    public let Fingerprint: String?

    /**
     * A server connect token for this user.
     */
    public let Sct: String?

    /**
     * The role of this user.
     */
    public let Role: String?

    public init(username: String, displayName: String? = nil, fingerprint: String? = nil, sct: String? = nil, role: String? = nil) {
        self.Username = username
        self.DisplayName = displayName
        self.Fingerprint = fingerprint
        self.Sct = sct
        self.Role = role
    }

    /**
     * Create an IamUser instance based on raw CBOR data.
     *
     * @param cbor Raw CBOR data (as received through a CoAP call to a Nabto Embedded SDK device).
     * @throws INVALID_RESPONSE If the specified data could not be decoded into an IamUser instance.
     * @return an IamUser instance representing the input raw CBOR data
     */
    public static func decode(cbor: Data) throws -> IamUser {
        let decoder = CBORDecoder()
        do {
            return try decoder.decode(IamUser.self, from: cbor)
        } catch {
            throw IamError.INVALID_RESPONSE(error: "\(error)")
        }
    }

    /**
     * Encode this user instance into CBOR data that can be sent to device.
     *
     * If using the IamUtil functions, this function is not necessary to use. But if you invoke the IAM CoAP backend
     * on the device directly, this function is useful for encoding input. For instance for the /iam/pairing/local-open endpoint
     * that accepts an encoded user (as documented on https://docs.nabto.com/developer/api-reference/coap/iam/pairing-local-open.html).
     *
     * @throws INVALID_INPUT If the user could not be encoded into CBOR data.
     * @return Raw CBOR data (e.g. to send to a CoAP call to a Nabto Embedded SDK device).
     */
    public func encode() throws -> Data {
        let encoder = CBOREncoder()
        do {
            return try encoder.encode(self)
        } catch {
            throw IamError.INVALID_INPUT
        }
    }

    /*
     * For debugging.
     */
    public func cborAsHex() -> String? {
        let encoder = CBOREncoder()
        return try? encoder.encode(self).map {
                    String(format: "%02hhx", $0)
                }
                .joined()
    }
}

/**
 * This struct contains detailed information about a Nabto Edge Embedded device.
 *
 * Note that upper camelcase field names breaks standard Swift style - the field names match
 * the key names in the CBOR string map for the "CoAP GET /iam/pairing" endpoint, see
 * https://docs.nabto.com/developer/api-reference/coap/iam/pairing.html
 */
public struct DeviceDetails: Codable {

    /**
     * Pairing modes currently available for use by the client.
     */
    public let Modes: [String]

    /**
     * The version of the Nabto Edge Embedded SDK.
     */
    public let NabtoVersion: String

    /**
     * The vendor assigned application version.
     */
    public let AppVersion: String?

    /**
     * The vendor assigned application name.
     */
    public let AppName: String?

    /**
     * The device's product id.
     */
    public let ProductId: String

    /**
     * The device's device id.
     */
    public let DeviceId: String

    internal init(Modes: [String], NabtoVersion: String, AppVersion: String, AppName: String, ProductId: String, DeviceId: String) {
        self.Modes = Modes
        self.NabtoVersion = NabtoVersion
        self.AppVersion = AppVersion
        self.AppName = AppName
        self.ProductId = ProductId
        self.DeviceId = DeviceId
    }

    /**
     * Create a DeviceDetails instance based on raw CBOR data.
     *
     * @param cbor Raw CBOR data (as received through a CoAP call to a Nabto Embedded SDK device).
     * @throws INVALID_RESPONSE If the specified data could not be decoded into a DeviceDetails instance.
     * @return a DeviceDetails instance representing the input raw CBOR data
     */
    public static func decode(cbor: Data) throws -> DeviceDetails {
        let decoder = CBORDecoder()
        do {
            return try decoder.decode(DeviceDetails.self, from: cbor)
        } catch {
            throw IamError.INVALID_RESPONSE(error: "\(error)")
        }
    }
}


