//
// Created by Ulrik Gammelby on 02/03/2022.
//

import Foundation
import XCTest

@testable import NabtoEdgeClient

class PairingUtilTests_HostedTestDevices : NabtoEdgeClientTestBase {

    func testPasswordOpen_Success_SameConnection() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try! self.connection.connect()

        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_Success_DifferentConnections() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try! self.connection.connect()

        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        let username = uniqueUser()
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")

        try! self.connection.close()
        try! self.connection = self.client.createConnection()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try! self.connection.connect()
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_InvalidUsername() {
        try! super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: "foo bar baz", password: "open-password")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.INVALID_INPUT)
        }
    }

    func testPasswordOpen_UsernameExists() {
        let device = self.testDevices.passwordProtectedDevice
        try! super.connect(device)
        let username = uniqueUser()
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testPasswordOpen_InvalidPassword() {
        try! super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: "wrong-password")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.AUTHENTICATION_ERROR)
        }
    }
}


class PairingUtilTests_LocalTestDevices : NabtoEdgeClientTestBase {

    func testPasswordOpen_Success() {
        let device = self.testDevices.localPasswordProtectedDevice
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)
    }

    func testPasswordOpen_BlockedByDeviceIamConfig() {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try! super.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: uniqueUser(), password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.PAIRING_MODE_DISABLED)
        }
    }

    func testLocalOpen_Success() {
        let device = self.testDevices.localPairLocalOpen
        try! self.connect(device)
        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        try! PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalOpen_InvalidUsername() {
        try! self.connect(self.testDevices.localPairLocalOpen)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: "foo bar baz")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.INVALID_INPUT)
        }
    }

    func testLocalOpen_UsernameExists() {
        let device = self.testDevices.localPairLocalOpen
        try! self.connect(device)
        let username = uniqueUser()
        try! PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testLocalOpen_BlockedByDeviceIamConfig() {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try! super.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: uniqueUser())) { error in
            XCTAssertEqual(error as! PairingError, PairingError.PAIRING_MODE_DISABLED)
        }
    }

    func testPasswordInvite_Success() {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try! PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try! self.connection.close()
        self.connection = try! client.createConnection()
        try! self.connect(device)
        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        try! PairingUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordInvite_WrongUser() {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try! PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try! self.connection.close()
        self.connection = try! client.createConnection()
        try! self.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairPasswordInvite(connection: self.connection, username: "wrongusername", password: guestPassword))  { error in
            XCTAssertEqual(error as! PairingError, PairingError.AUTHENTICATION_ERROR)
        }
    }

    func testCreateUser_BadRole() {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

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
        try! super.connect(device)
        XCTAssertFalse(try PairingUtil.isCurrentUserPaired(connection: self.connection))
        XCTAssertThrowsError(try PairingUtil.getCurrentUser(connection: self.connection)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USER_IS_NOT_PAIRED)
        }
    }

    func testCreateUser_and_GetUser() throws {
        let device = self.testDevices.localPasswordInvite
        let admin = uniqueUser()
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)
        XCTAssertTrue(try PairingUtil.isCurrentUserPaired(connection: self.connection))

        let guest = uniqueUser()
        let guestPassword = "guestpassword"
        try PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: guestPassword,
                        role: "Guest")

        // currently connected as admin - connect as new user
        try! self.connection.close()
        self.connection = try! client.createConnection()
        try! self.connect(device)
        try! PairingUtil.pairPasswordInvite(connection: self.connection, username: guest, password: guestPassword)

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

    func testCodableUser() {
        let user = PairingUtil.User(username: "username-foobarbaz", sct: "sct-qux")
        let cbor = try! user.encode()
        let decoded = try! PairingUtil.User.decode(cbor: cbor)
        XCTAssertEqual(user.Username, decoded.Username)
        XCTAssertEqual(user.Sct, decoded.Sct)
    }

}

class PairingUtilTests_LocalTestDevices_NeedCleanState : NabtoEdgeClientTestBase {

    func testLocalInitial_Success() {
        let device = self.testDevices.localPairLocalInitial
        try! self.connect(device)
        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        try! PairingUtil.pairLocalInitial(connection: self.connection)
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testLocalInitial_Fail_AlreadyPaired() {
        let device = self.testDevices.localPairLocalInitial
        try! self.connect(device)
        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        try! PairingUtil.pairLocalInitial(connection: self.connection)
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
        XCTAssertThrowsError(try PairingUtil.pairLocalInitial(connection: self.connection) ) { error in
            XCTAssertEqual(error as? PairingError, .INITIAL_USER_ALREADY_PAIRED)
        }
    }

}