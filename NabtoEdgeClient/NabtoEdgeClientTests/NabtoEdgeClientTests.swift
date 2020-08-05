//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
import NabtoEdgeClient

class NabtoEdgeClientTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testVersionString() throws {
        XCTAssertEqual("5.", NabtoEdgeClient.versionString().prefix(2))
    }

    func testCreateClientConnection() throws {
        let client = NabtoEdgeClient()
        let _ = try client.createConnection()
    }

    func testDefaultLog() {
        let client = NabtoEdgeClient()
        client.enableNsLogLogging()
        let _ = try! client.createConnection()
    }

    func testSetLogLevelValid() {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\",\n\"DeviceId\": \"de-12345678\",\n\"ServerUrl\": \"https://pr-12345678.clients.nabto.net\",\n\"ServerKey\": \"sk-12345678123456781234567812345678\"\n}")
    }

    func testSetLogLevelInvalid() {
        let client = NabtoEdgeClient()
        XCTAssertThrowsError(try client.setLogLevel(level: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCreatePrivateKey() {
        let client = NabtoEdgeClient()
        let key = try! client.createPrivateKey()
        XCTAssertTrue(key.contains("BEGIN EC PRIVATE KEY"))
    }

    func testSetOptionsBadJson() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.updateOptions(json: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsInvalidParameter() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.updateOptions(json: "{\n\"ProductFoo\": \"...\"}")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsValid() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\",\n\"DeviceId\": \"de-12345678\",\n\"ServerUrl\": \"https://pr-12345678.clients.nabto.net\",\n\"ServerKey\": \"sk-12345678123456781234567812345678\"\n}")
    }

    func testGetOptions() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\"}")
        let allOptions = try! connection.getOptions()
        XCTAssertTrue(allOptions.contains("ProductId"))
        XCTAssertTrue(allOptions.contains("pr-12345678"))
    }

    func testGetDeviceFingerprintHex() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        // TODO - we need some public, always-on test device for wrapper tests (as bs cannot bs+device cannot be embedded for self-contained test)
    }

    func testGetDeviceFingerprintHexFail() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.getDeviceFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testGetClientFingerprintHex() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        // TODO - we need some public, always-on test device for wrapper tests (as bs cannot bs+Client cannot be embedded for self-contained test)
    }

    func testGetClientFingerprintHexFail() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.getClientFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

}
