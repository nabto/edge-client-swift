//
// Created by Ulrik Gammelby on 02/03/2022.
//

import Foundation
import XCTest

@testable import NabtoEdgeClient

class IamUtilTests_HostedTestDevices: NabtoEdgeClientTestBase {

    func testPasswordOpen_Success_SameConnection() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()

        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_Success_DifferentConnections() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()

        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")

        try self.connection.close()
        try self.connection = self.client.createConnection()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_InvalidUsername() throws {
        try super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: "foo bar baz", password: "open-password")) { error in
            XCTAssertEqual(error as? IamError, IamError.INVALID_INPUT)
        }
    }

    func testPasswordOpen_UsernameExists() throws {
        let device = self.testDevices.passwordProtectedDevice
        try super.connect(device)
        let username = uniqueUser()
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)
        XCTAssertThrowsError(try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)) { error in
            XCTAssertEqual(error as? IamError, IamError.USERNAME_EXISTS)
        }
    }

    func testPasswordOpen_InvalidPassword() throws {
        try super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: "wrong-password")) { error in
            XCTAssertEqual(error as? IamError, IamError.AUTHENTICATION_ERROR)
        }
    }
}


class IamUtilTests_LocalTestDevices: NabtoEdgeClientTestBase {

    let localInitialAdminKey = """
                               -----BEGIN EC PRIVATE KEY-----
                               MHcCAQEEIAl3ZURem5NMCTZA0OeTPcT7y6T2FHjHhmQz54UiH7mQoAoGCCqGSM49
                               AwEHoUQDQgAEbiabrII+WZ8ABD4VQpmLe3cSIWdQfrRbxXotx5yxwInfgLuDU+rq
                               OIFReqTf5h+Nwp/jj00fnsII88n1YCveoQ==
                               -----END EC PRIVATE KEY-----
                               """

    func testPasswordOpen_Success() throws {
        let device = self.testDevices.localPairPasswordOpen
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)
    }

    func testPasswordOpen_InvalidPassword() throws {
        try super.connect(self.testDevices.localPairPasswordOpen)
        XCTAssertThrowsError(try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: "wrong-password")) { error in
            XCTAssertEqual(error as? IamError, IamError.AUTHENTICATION_ERROR)
        }
    }

    func testPasswordOpen_BlockedByDeviceIamConfig() throws {
        // This device has open password pairing disabled in IAM config (not state) - hence expect
        // BLOCKED_BY_DEVICE_CONFIGURATION and not AUTHENTICATION_ERROR.
        //
        // A note on AUTHENTICATION_ERROR vs PAIRING_MODE_DISABLED: The former would be seen if open
        // password pairing was enabled in config but disabled in state (and not PAIRING_MODE_DISABLED as
        // intuitively expected): An auth listener is not started if a password pairing mode is not
        // enabled. And if no auth listener is enabled, the password auth step fails that happens prior to
        // the pairing attempt, hence AUTHENTICATION_ERROR in that case.
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try super.connect(device)
        XCTAssertThrowsError(try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)) { error in
            XCTAssertEqual(error as? IamError, IamError.BLOCKED_BY_DEVICE_CONFIGURATION)
        }
    }

    func testPasswordOpen_Async_Success() throws {
        let device = self.testDevices.localPairPasswordOpen
        try super.connect(device)
        let exp = XCTestExpectation(description: "pairing done")
        var err: IamError? = nil
        try IamUtil.pairPasswordOpenAsync(
                connection: self.connection,
                desiredUsername: uniqueUser(),
                password: device.password) { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(err)
        XCTAssertEqual(err , IamError.OK)
    }

    func testPasswordOpen_Async_InvalidInput() throws {
        let device = self.testDevices.localPairPasswordOpen
        try super.connect(device)
        let exp = XCTestExpectation(description: "pairing done")
        var err: IamError? = nil
        try IamUtil.pairPasswordOpenAsync(
                connection: self.connection,
                desiredUsername: "",
                password: device.password) { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(err)
        XCTAssertEqual(err , IamError.INVALID_INPUT)
    }

    func testPasswordOpen_Async_AuthFail() throws {
        let device = self.testDevices.localPairPasswordOpen
        try super.connect(device)
        let exp = XCTestExpectation(description: "pairing done")
        var err: IamError? = nil
        try IamUtil.pairPasswordOpenAsync(
                connection: self.connection,
                desiredUsername: uniqueUser(),
                password: "wrong-password") { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(err)
        XCTAssertEqual(err , IamError.AUTHENTICATION_ERROR)
    }

    func testLocalOpen_Success() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalOpen_InvalidUsername() throws {
        try self.connect(self.testDevices.localPairLocalOpen)
        XCTAssertThrowsError(try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: "foo bar baz")) { error in
            XCTAssertEqual(error as? IamError, IamError.INVALID_INPUT)
        }
    }

    func testLocalOpen_UsernameExists() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        let username = uniqueUser()
        try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)
        XCTAssertThrowsError(try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)) { error in
            XCTAssertEqual(error as? IamError, IamError.USERNAME_EXISTS)
        }
    }

    func testLocalOpen_BlockedByDeviceIamConfig() throws {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try super.connect(device)
        XCTAssertThrowsError(try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())) { error in
            XCTAssertEqual(error as? IamError, IamError.PAIRING_MODE_DISABLED)
        }
    }

    func testLocalOpen_Async_Success() throws {
        let device = self.testDevices.localPairLocalOpen
        try super.connect(device)
        let exp = XCTestExpectation(description: "pairing done")
        var err: IamError? = nil
        try IamUtil.pairLocalOpenAsync(
                connection: self.connection,
                desiredUsername: uniqueUser()) { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(err)
        XCTAssertEqual(err , IamError.OK)
    }

    func testLocalOpen_Async_Fail() throws {
        let device = self.testDevices.localPairLocalOpen
        try super.connect(device)
        let exp = XCTestExpectation(description: "pairing done")
        var err: IamError? = nil
        try IamUtil.pairLocalOpenAsync(
                connection: self.connection,
                desiredUsername: "") { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertNotNil(err)
        XCTAssertEqual(err , IamError.INVALID_INPUT)
    }

    func testPasswordInvite_Success() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try IamUtil.createUser(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        try IamUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordInvite_WrongUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try IamUtil.createUser(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        XCTAssertThrowsError(try IamUtil.pairPasswordInvite(connection: self.connection, username: "wrongusername", password: guestPassword))  { error in
            XCTAssertEqual(error as? IamError, IamError.AUTHENTICATION_ERROR)
        }
    }

    func testCreateUser_BadRole() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        XCTAssertThrowsError(try IamUtil.createUser(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "unexistingrole"))
        { error in
            XCTAssertEqual(error as? IamError, IamError.ROLE_DOES_NOT_EXIST)
        }
    }

    func testCheckUnpairedUser() throws {
        let device = self.testDevices.localPasswordInvite
        try super.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: self.connection))
        XCTAssertThrowsError(try IamUtil.getCurrentUser(connection: self.connection)) { error in
            XCTAssertEqual(error as? IamError, IamError.USER_IS_NOT_PAIRED)
        }
    }

    func testCheckUnpairedUser_Async() throws {
        let device = self.testDevices.localPasswordInvite
        try super.connect(device)
        let exp = XCTestExpectation(description: "invocation done")
        var err: IamError? = nil
        var res: Bool!
        IamUtil.isCurrentUserPairedAsync(connection: self.connection) { error, isPaired in
            err = error
            res = isPaired
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(err, .OK)
        XCTAssertNotNil(res)
        XCTAssertFalse(res)
    }

    func testCheckPairedUser_Async() throws { // sync version tested in other tests
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())
        let exp = XCTestExpectation(description: "invocation done")
        var err: IamError? = nil
        var res: Bool!
        IamUtil.isCurrentUserPairedAsync(connection: connection) { error, isPaired in
            err = error
            res = isPaired
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(err, .OK)
        XCTAssertNotNil(res)
        XCTAssertTrue(res)
    }

    func testCreateUser_and_GetUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try IamUtil.createUser(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        try IamUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)

        // guest is not allowed to get admin user
        XCTAssertThrowsError(try IamUtil.getUser(connection: self.connection, username: admin)) { error in
            XCTAssertEqual(error as? IamError, IamError.BLOCKED_BY_DEVICE_CONFIGURATION)
        }

        // guest can get self
        let me = try IamUtil.getUser(connection: self.connection, username: guest)
        XCTAssertEqual(me.Username, guest)
        XCTAssertEqual(me.Role, "Guest")
    }

    func testCreateUser_and_GetUser_Async() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"

        let expCreate = XCTestExpectation(description: "create user invocation done")

        var err: IamError? = nil
        try IamUtil.createUserAsync(
                connection: self.connection,
                username: guest,
                password: guestPassword,
                role: "Guest") { error in
            err = error
            expCreate.fulfill()
        }
        wait(for: [expCreate], timeout: 2.0)
        XCTAssertEqual(err, .OK)

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        try IamUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)

        let expGetUser = XCTestExpectation(description: "get user invocation done")
        err = nil
        var me: IamUser!
        IamUtil.getCurrentUserAsync(connection: self.connection) { error, user in
            err = error
            me = user
            expGetUser.fulfill()
        }
        wait(for: [expGetUser], timeout: 2.0)
        XCTAssertEqual(err, .OK)
        XCTAssertEqual(me.Username, guest)
        XCTAssertEqual(me.Role, "Guest")
    }

    func testSetDisplayName() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        let displayName = uniqueUser()
        try IamUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)
        try IamUtil.updateUserDisplayName(connection: self.connection, username: username, displayName: displayName)
        let user = try IamUtil.getCurrentUser(connection: connection)
        XCTAssertEqual(user.DisplayName, displayName)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testDeleteUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try IamUtil.createUser(
                connection: self.connection,
                username: guest,
                password: guestPassword,
                role: "Guest")

        let guestUser = try IamUtil.getUser(connection: self.connection, username: guest)
        XCTAssertEqual(guestUser.Username, guest)
        XCTAssertEqual(guestUser.Role, "Guest")

        XCTAssertThrowsError(try IamUtil.deleteUser(connection: self.connection, username: "user-does-not-exist")) { error in
            XCTAssertEqual(error as? IamError, .USER_DOES_NOT_EXIST)
        }

        try IamUtil.deleteUser(connection: self.connection, username: guest)

        XCTAssertThrowsError(try IamUtil.getUser(connection: self.connection, username: guest)) { error in
            XCTAssertEqual(error as? IamError, .USER_DOES_NOT_EXIST)
        }

    }

    func testDeleteUser_Async() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try IamUtil.createUser(
                connection: self.connection,
                username: guest,
                password: guestPassword,
                role: "Guest")

        let guestUser = try IamUtil.getUser(connection: self.connection, username: guest)
        XCTAssertEqual(guestUser.Username, guest)
        XCTAssertEqual(guestUser.Role, "Guest")

        let exp = XCTestExpectation(description: "delete done")
        var err: IamError? = nil
        try IamUtil.deleteUserAsync(connection: self.connection, username: guest) { error in
            err = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(err, IamError.OK)
        XCTAssertThrowsError(try IamUtil.getUser(connection: self.connection, username: guest)) { error in
            XCTAssertEqual(error as? IamError, .USER_DOES_NOT_EXIST)
        }

    }

    func testCodableUser() throws {
        let user = IamUser(username: "username-foobarbaz", sct: "sct-qux")
        let cbor = try user.encode()
        let decoded = try IamUser.decode(cbor: cbor)
        XCTAssertEqual(user.Username, decoded.Username)
        XCTAssertEqual(user.Sct, decoded.Sct)
    }

    func resetLocalInitialPairingState(_ connection: Connection) throws {
        let initialUser = "admin"
        let tmpUser = uniqueUser()
        let currentUser: IamUser
        do {
            currentUser = try IamUtil.getCurrentUser(connection: connection)
        } catch {
            return
        }
        XCTAssertEqual(currentUser.Username, initialUser)
        try IamUtil.renameUser(connection: connection, username: initialUser, newUsername: tmpUser)
        try IamUtil.createUser(connection: connection, username: initialUser, password: "", role: "Administrator")
        try IamUtil.deleteUser(connection: connection, username: tmpUser)
    }

    func connectLocalInitial(_ client: Client) throws -> Connection {
        let device = self.testDevices.localPairLocalInitial
        return try connectToDevice(client, device)
    }

    func connectToDevice(_ client: Client, _ device: TestDevice) throws -> Connection {
        try self.enableLogging(client)
        let connection = try client.createConnection()
        try connection.setPrivateKey(key: self.localInitialAdminKey)
        try connection.updateOptions(json: device.asJson())
        try connection.connect()
        try self.resetLocalInitialPairingState(connection)
        return connection
    }


    func testLocalInitial_Success() throws {
        let client = Client()
        let connection = try connectLocalInitial(client)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        try IamUtil.pairLocalInitial(connection: connection)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalInitial_Fail_AlreadyPaired() throws {
        let client = Client()
        let connection = try connectLocalInitial(client)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))
        try IamUtil.pairLocalInitial(connection: connection)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
        XCTAssertThrowsError(try IamUtil.pairLocalInitial(connection: connection) ) { error in
            XCTAssertEqual(error as? IamError, .INITIAL_USER_ALREADY_PAIRED)
        }
    }

    func testGetDeviceDetails() throws {
        let client = Client()
        let device = self.testDevices.localPairLocalInitial
        let connection = try connectToDevice(client, device)
        let details = try IamUtil.getDeviceDetails(connection: connection)
        XCTAssertEqual(details.ProductId, device.productId)
        XCTAssertEqual(details.DeviceId, device.deviceId)
        XCTAssertEqual(details.Modes, ["LocalInitial"])
    }

    func testGetDeviceDetails_Async_Success() throws {
        let client = Client()
        let device = self.testDevices.localPairLocalInitial
        let connection = try connectToDevice(client, device)
        let exp = XCTestExpectation(description: "invocation done")
        var err: IamError? = nil
        var details: DeviceDetails!
        try IamUtil.getDeviceDetailsAsync(connection: connection) { (error: IamError, result: DeviceDetails?) in
            err = error
            details = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(err, .OK)
        XCTAssertEqual(details.ProductId, device.productId)
        XCTAssertEqual(details.DeviceId, device.deviceId)
        XCTAssertEqual(details.Modes, ["LocalInitial"])
    }

    func testGetDeviceDetails_Async_Fail() throws {
        let client = Client()
        let device = self.testDevices.localMdnsDevice
        let connection = try connectToDevice(client, device)
        let exp = XCTestExpectation(description: "invocation done")
        var err: IamError? = nil
        var details: DeviceDetails!
        try IamUtil.getDeviceDetailsAsync(connection: connection) { (error: IamError, result: DeviceDetails?) in
            err = error
            details = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(err, .IAM_NOT_SUPPORTED)
        XCTAssertNil(details)
    }

    func testGetPairingModes_1() throws {
        let device = self.testDevices.localPasswordInvite
        let connection = try connectToDevice(client, device)
        let modes = try IamUtil.getAvailablePairingModes(connection: connection)
        XCTAssertEqual(modes.count, 2)
        XCTAssertTrue(modes.contains(.PasswordInvite))
        XCTAssertTrue(modes.contains(.PasswordOpen))
    }

    func testGetPairingModes_1_Async() throws {
        let client = Client()
        let device = self.testDevices.localPasswordInvite
        let connection = try connectToDevice(client, device)
        let exp = XCTestExpectation(description: "invocation done")
        var err: IamError? = nil
        var modes: [PairingMode]!
        try IamUtil.getAvailablePairingModesAsync(connection: connection) { (error: IamError, result: [PairingMode]?) in
            err = error
            modes = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(err, .OK)
        XCTAssertEqual(modes.count, 2)
        XCTAssertTrue(modes.contains(.PasswordInvite))
        XCTAssertTrue(modes.contains(.PasswordOpen))
    }

    func testGetPairingModes_2() throws {
        let client = Client()
        let device = self.testDevices.localPairLocalInitial
        let connection = try connectToDevice(client, device)
        let modes = try IamUtil.getAvailablePairingModes(connection: connection)
        XCTAssertEqual(modes.count, 1)
        XCTAssertTrue(modes.contains(.LocalInitial))
    }

    func testGetPairingModes_3() throws {
        let device = self.testDevices.localPairLocalOpen
        let connection = try connectToDevice(client, device)
        let modes = try IamUtil.getAvailablePairingModes(connection: connection)
        XCTAssertEqual(modes.count, 1)
        XCTAssertTrue(modes.contains(.LocalOpen))
    }

    func createAdminAndGuest(device: TestDevice, guestPassword: String) throws -> String {
        let admin = uniqueUser()
        try super.connect(device)
        try IamUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let user = uniqueUser()
        try IamUtil.createUser(
                connection: self.connection,
                username: user,
                password: guestPassword,
                role: "Guest")

        return user
    }

    func doTestUpdateUserPassword(updateFunc: (Connection, String, String) throws -> ()) throws {
        let device = self.testDevices.localPasswordInvite
        let guestPassword = "guestpassword"
        let user = try self.createAdminAndGuest(device: device, guestPassword: guestPassword)

        let newGuestPassword = "newguestpassword"

        // gracefully handle bad username
        XCTAssertThrowsError(try updateFunc(self.connection, "baduser", "blah")) { error in
            XCTAssertEqual(error as? IamError, IamError.USER_DOES_NOT_EXIST)
        }

        // sunshine scenario
        try updateFunc(self.connection, user, newGuestPassword)

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        XCTAssertFalse(try IamUtil.isCurrentUserPaired(connection: connection))

        // confirm initial password no longer works
        XCTAssertThrowsError(try IamUtil.pairPasswordInvite(connection: self.connection, username: user, password: guestPassword)) { error in
            XCTAssertEqual(error as? IamError, IamError.AUTHENTICATION_ERROR)
        }
        try IamUtil.pairPasswordInvite(connection: self.connection, username: user, password: newGuestPassword)
        XCTAssertTrue(try IamUtil.isCurrentUserPaired(connection: connection))
    }

    func testUpdateUserPassword_Sync() throws {
        try doTestUpdateUserPassword { connection, username, password in
            try IamUtil.updateUserPassword(connection: connection, username: username, password: password)
        }
    }

    func testUpdateUserPassword_Async() throws {
        try doTestUpdateUserPassword { connection, username, password in
            let exp = XCTestExpectation(description: "set password done")
            var err: IamError? = nil
            try IamUtil.updateUserPasswordAsync(connection: connection, username: username, password: password) { error in
                exp.fulfill()
                err = error
            }
            wait(for: [exp], timeout: 2.0)
            if (err != IamError.OK) {
                throw err!
            }
        }
    }

    func doTestUpdateUserRole(updateFunc: (Connection, String, String) throws -> ()) throws {
        let device = self.testDevices.localPasswordInvite
        let guestPassword = "guestpassword"
        let user = try self.createAdminAndGuest(device: device, guestPassword: guestPassword)

        let newRole = "Standard"

        // gracefully handle bad role name
        XCTAssertThrowsError(try updateFunc(self.connection, user, "badrole")) { error in
            XCTAssertEqual(error as? IamError, IamError.ROLE_DOES_NOT_EXIST)
        }

        // sunshine scenario
        try updateFunc(self.connection, user, newRole)

        let userObj = try IamUtil.getUser(connection: self.connection, username: user)
        XCTAssertEqual(userObj.Role, newRole)
    }

    func testUpdateUserRole_Sync() throws {
        try doTestUpdateUserRole { connection, username, role in
            try IamUtil.updateUserRole(connection: connection, username: username, role: role)
        }
    }

    func testUpdateUserRole_Async() throws {
        try doTestUpdateUserRole { connection, username, role in
            let exp = XCTestExpectation(description: "update role done")
            var err: IamError? = nil
            try IamUtil.updateUserRoleAsync(connection: connection, username: username, role: role) { error in
                exp.fulfill()
                err = error
            }
            wait(for: [exp], timeout: 2.0)
            if (err != IamError.OK) {
                throw err!
            }
        }
    }

    func doTestUpdateUserDisplayName(updateFunc: (Connection, String, String) throws -> ()) throws {
        let device = self.testDevices.localPasswordInvite
        let guestPassword = "guestpassword"
        let user = try self.createAdminAndGuest(device: device, guestPassword: guestPassword)

        let newDisplayName = "Foo Barsen"

        // gracefully handle bad user name
        XCTAssertThrowsError(try updateFunc(self.connection, "unexistinguser", newDisplayName)) { error in
            XCTAssertEqual(error as? IamError, IamError.USER_DOES_NOT_EXIST)
        }

        // sunshine scenario
        try updateFunc(self.connection, user, newDisplayName)

        let userObj = try IamUtil.getUser(connection: self.connection, username: user)
        XCTAssertEqual(userObj.DisplayName, newDisplayName)
    }

    func testUpdateUserDisplayName_Sync() throws {
        try doTestUpdateUserDisplayName { connection, username, displayName in
            try IamUtil.updateUserDisplayName(connection: connection, username: username, displayName: displayName)
        }
    }

    func testUpdateUserDisplayName_Async() throws {
        try doTestUpdateUserDisplayName { connection, username, displayName in
            let exp = XCTestExpectation(description: "set password done")
            var err: IamError? = nil
            try IamUtil.updateUserDisplayNameAsync(connection: connection, username: username, displayName: displayName) { error in
                exp.fulfill()
                err = error
            }
            wait(for: [exp], timeout: 2.0)
            if (err != IamError.OK) {
                throw err!
            }
        }
    }

    func doTestRenameUser(updateFunc: (Connection, String, String) throws -> ()) throws {
        let device = self.testDevices.localPasswordInvite
        let guestPassword = "guestpassword"
        let user = try self.createAdminAndGuest(device: device, guestPassword: guestPassword)

        let newUsername = uniqueUser()

        // gracefully handle bad user name
        XCTAssertThrowsError(try updateFunc(self.connection, "unexistinguser", newUsername)) { error in
            XCTAssertEqual(error as? IamError, IamError.USER_DOES_NOT_EXIST)
        }

        // sunshine scenario
        try updateFunc(self.connection, user, newUsername)

        XCTAssertThrowsError(try IamUtil.getUser(connection: self.connection, username: user)) { error in
            XCTAssertEqual(error as? IamError, IamError.USER_DOES_NOT_EXIST)
        }

        let userObj = try IamUtil.getUser(connection: self.connection, username: newUsername)
        XCTAssertEqual(userObj.Username, newUsername)
    }

    func testRenameUser_Sync() throws {
        try doTestRenameUser { connection, username, newUsername in
            try IamUtil.renameUser(connection: connection, username: username, newUsername: newUsername)
        }
    }

    func testRenameUser_Async() throws {
        try doTestRenameUser { connection, username, newUsername in
            let exp = XCTestExpectation(description: "rename done")
            var err: IamError? = nil
            try IamUtil.renameUserAsync(connection: connection, username: username, newUsername: newUsername) { error in
                exp.fulfill()
                err = error
            }
            wait(for: [exp], timeout: 2.0)
            if (err != IamError.OK) {
                throw err!
            }
        }
    }


}