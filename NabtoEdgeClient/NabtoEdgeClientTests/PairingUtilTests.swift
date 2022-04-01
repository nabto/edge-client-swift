//
// Created by Ulrik Gammelby on 02/03/2022.
//

import Foundation
import XCTest

@testable import NabtoEdgeClient

class PairingUtilTests_HostedTestDevices : NabtoEdgeClientTestBase {

    func testPasswordOpen_Success_SameConnection() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()

        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_Success_DifferentConnections() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()

        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")

        try self.connection.close()
        try self.connection = self.client.createConnection()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_InvalidUsername() throws {
        try super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: "foo bar baz", password: "open-password")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.INVALID_INPUT)
        }
    }

    func testPasswordOpen_UsernameExists() throws {
        let device = self.testDevices.passwordProtectedDevice
        try super.connect(device)
        let username = uniqueUser()
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testPasswordOpen_InvalidPassword() throws {
        try super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: "wrong-password")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.AUTHENTICATION_ERROR)
        }
    }
}


class PairingUtilTests_LocalTestDevices : NabtoEdgeClientTestBase {

    let localInitialAdminKey = """
                               -----BEGIN EC PRIVATE KEY-----
                               MHcCAQEEIAl3ZURem5NMCTZA0OeTPcT7y6T2FHjHhmQz54UiH7mQoAoGCCqGSM49
                               AwEHoUQDQgAEbiabrII+WZ8ABD4VQpmLe3cSIWdQfrRbxXotx5yxwInfgLuDU+rq
                               OIFReqTf5h+Nwp/jj00fnsII88n1YCveoQ==
                               -----END EC PRIVATE KEY-----
                               """

    func testPasswordOpen_Success() throws {
        let device = self.testDevices.localPasswordProtectedDevice
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)
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
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.BLOCKED_BY_DEVICE_CONFIGURATION)
        }
    }

    func testLocalOpen_Success() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalOpen_InvalidUsername() throws {
        try self.connect(self.testDevices.localPairLocalOpen)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: "foo bar baz")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.INVALID_INPUT)
        }
    }

    func testLocalOpen_UsernameExists() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        let username = uniqueUser()
        try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testLocalOpen_BlockedByDeviceIamConfig() throws {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try super.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())) { error in
            XCTAssertEqual(error as! PairingError, PairingError.PAIRING_MODE_DISABLED)
        }
    }

    func testPasswordInvite_Success() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        try PairingUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordInvite_WrongUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairPasswordInvite(connection: self.connection, username: "wrongusername", password: guestPassword))  { error in
            XCTAssertEqual(error as! PairingError, PairingError.AUTHENTICATION_ERROR)
        }
    }

    func testCreateUser_BadRole() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        XCTAssertThrowsError(try PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "unexistingrole"))
        { error in
            XCTAssertEqual(error as! PairingError, PairingError.ROLE_DOES_NOT_EXIST)
        }
    }

    func testCheckUnpairedUser() throws {
        let device = self.testDevices.localPasswordInvite
        try super.connect(device)
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: self.connection))
        XCTAssertThrowsError(try PairingUtil.getCurrentUser(connection: self.connection)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USER_IS_NOT_PAIRED)
        }
    }

    func testCreateUser_and_GetUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try self.connection.close()
        self.connection = try client.createConnection()
        try self.connect(device)
        try PairingUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)

        // guest is not allowed to get admin user
        XCTAssertThrowsError(try PairingUtil.getUser(connection: self.connection, username: admin)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.BLOCKED_BY_DEVICE_CONFIGURATION)
        }

        // guest can get self
        let me = try PairingUtil.getUser(connection: self.connection, username: guest)
        XCTAssertEqual(me.Username, guest)
        XCTAssertEqual(me.Role, "Guest")
    }

    func testDeleteUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try super.connect(device)
        try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try PairingUtil.createNewUserForInvitePairing(
                connection: self.connection,
                username: guest,
                password: guestPassword,
                role: "Guest")

        let guestUser = try PairingUtil.getUser(connection: self.connection, username: guest)
        XCTAssertEqual(guestUser.Username, guest)
        XCTAssertEqual(guestUser.Role, "Guest")

        try PairingUtil.deleteUser(connection: self.connection, username: guest)

        XCTAssertThrowsError(try PairingUtil.getUser(connection: self.connection, username: guest)) { error in
            XCTAssertEqual(error as? PairingError, .USER_DOES_NOT_EXIST)
        }

    }

    func testCodableUser() throws {
        let user = PairingUtil.User(username: "username-foobarbaz", sct: "sct-qux")
        let cbor = try user.encode()
        let decoded = try PairingUtil.User.decode(cbor: cbor)
        XCTAssertEqual(user.Username, decoded.Username)
        XCTAssertEqual(user.Sct, decoded.Sct)
    }

    func resetLocalInitialPairingState(_ connection: Connection) throws {
        let initialUser = "admin"
        let tmpUser = uniqueUser()
        let currentUser: PairingUtil.User
        do {
            currentUser = try PairingUtil.getCurrentUser(connection: connection)
        } catch {
            return
        }
        XCTAssertEqual(currentUser.Username, initialUser)
        try PairingUtil.renameUser(connection: connection, username: initialUser, newUsername: tmpUser)
        try PairingUtil.createNewUserForInvitePairing(connection: connection, username: initialUser, password: "", role: "Administrator")
        try PairingUtil.deleteUser(connection: connection, username: tmpUser)
    }

    func connectLocalInitial(_ client: Client) throws -> Connection {
        let device = self.testDevices.localPairLocalInitial
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
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        try PairingUtil.pairLocalInitial(connection: connection)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalInitial_Fail_AlreadyPaired() throws {
        let client = Client()
        let connection = try connectLocalInitial(client)
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: connection))
        try PairingUtil.pairLocalInitial(connection: connection)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: connection))
        XCTAssertThrowsError(try PairingUtil.pairLocalInitial(connection: connection) ) { error in
            XCTAssertEqual(error as? PairingError, .INITIAL_USER_ALREADY_PAIRED)
        }
    }

    func testGetDeviceDetails() throws {
        let client = Client()
        let connection = try connectLocalInitial(client)
        let details = try PairingUtil.getDeviceDetails(connection: connection)
        let device = self.testDevices.localPairLocalInitial
        XCTAssertEqual(details.ProductId, device.productId)
        XCTAssertEqual(details.DeviceId, device.deviceId)
        XCTAssertEqual(details.Modes, ["LocalInitial"])
    }

    func testGetPairingModes_1() throws {
        let device = self.testDevices.localPasswordInvite
        try self.connect(device)
        let modes = try PairingUtil.getAvailablePairingModes(connection: connection)
        XCTAssertTrue(modes.contains(.PasswordInvite))
        XCTAssertTrue(modes.contains(.PasswordOpen))
    }

    func testGetPairingModes_2() throws {
        let client = Client()
        let connection = try connectLocalInitial(client)
        let modes = try PairingUtil.getAvailablePairingModes(connection: connection)
        XCTAssertTrue(modes.contains(.LocalInitial))
    }

    func testGetPairingModes_3() throws {
        let device = self.testDevices.localPairLocalOpen
        try self.connect(device)
        let modes = try PairingUtil.getAvailablePairingModes(connection: connection)
        XCTAssertTrue(modes.contains(.LocalOpen))
    }

}