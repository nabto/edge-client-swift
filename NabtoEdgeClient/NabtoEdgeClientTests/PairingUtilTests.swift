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
        let username = UUID().uuidString.lowercased()
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: "open-password")
        XCTAssertTrue(try! PairingUtil.isCurrentUserPaired(connection: connection))
    }

    func testPasswordOpen_Success_DifferentConnections() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try! self.connection.connect()

        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        let username = UUID().uuidString.lowercased()
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
        let username = UUID().uuidString.lowercased()
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: username, password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testPasswordOpen_InvalidPassword() {
        try! super.connect(self.testDevices.passwordProtectedDevice)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: UUID().uuidString.lowercased(), password: "wrong-password")) { error in
            XCTAssertEqual(error as! PairingError, PairingError.AUTHENTICATION_ERROR)
        }
    }
}


class PairingUtilTests_LocalTestDevices : NabtoEdgeClientTestBase {

    func testPasswordOpen_Success() {
        let device = self.testDevices.localPasswordProtectedDevice
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: UUID().uuidString.lowercased(), password: device.password)
    }

    func testPasswordOpen_BlockedByDeviceIamConfig() {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try! super.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: UUID().uuidString.lowercased(), password: device.password)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.PAIRING_MODE_DISABLED)
        }
    }

    func testLocalOpen_Success() {
        let device = self.testDevices.localPairLocalOpen
        try! self.connect(device)
        XCTAssertFalse(try! PairingUtil.isCurrentUserPaired(connection: connection))
        try! PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: UUID().uuidString.lowercased())
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
        let username = UUID().uuidString.lowercased()
        try! PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: username)) { error in
            XCTAssertEqual(error as! PairingError, PairingError.USERNAME_EXISTS)
        }
    }

    func testLocalOpen_BlockedByDeviceIamConfig() {
        let device = self.testDevices.localPasswordPairingDisabledConfig
        try! super.connect(device)
        XCTAssertThrowsError(try PairingUtil.pairLocalOpen(connection: self.connection, desiredUsername: UUID().uuidString.lowercased())) { error in
            XCTAssertEqual(error as! PairingError, PairingError.PAIRING_MODE_DISABLED)
        }
    }

    func testPasswordInvite_Success() {
        let device = self.testDevices.localPasswordInvite
        let admin = UUID().uuidString.lowercased()
        try! super.connect(device)
        try! PairingUtil.pairPasswordOpen(connection: self.connection, desiredUsername: admin, password: device.password)

        let guest = UUID().uuidString.lowercased()
        try! PairingUtil.createNewUserForInvitePairing(
                        connection: self.connection,
                        username: guest,
                        password: "guestpassword",
                        role: "guest")
    }

    func testCodableUser() {
        let user = PairingUtil.User(username: "username-foobarbaz", sct: "sct-qux")
        let cbor = try! user.encode()
        let decoded = try! PairingUtil.User.decode(cbor: cbor)
        XCTAssertEqual(user.Username, decoded.Username)
        XCTAssertEqual(user.Sct, decoded.Sct)
    }

}