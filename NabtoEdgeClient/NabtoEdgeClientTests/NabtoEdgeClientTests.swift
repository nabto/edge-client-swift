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

    func connect() throws -> Connection {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        let connection: Connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: """
                                            {\n
                                            \"ProductId\": \"pr-fatqcwj9\",\n
                                            \"DeviceId\": \"de-3x4st7ru\",\n
                                            \"ServerUrl\": \"https://pr-fatqcwj9.clients.nabto.net\",\n
                                            \"ServerKey\": \"sk-5f3ab4bea7cc2585091539fb950084ce\"\n}
                                            """)
        try! connection.connect()
        return connection
    }

    func testConnect() {
        try! connect().close()
    }

    func testConnectFail() {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        let connection: Connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: """
                                            {\n
                                            \"ProductId\": \"pr-fatqcwj9\",\n
                                            \"DeviceId\": \"de-zqw7vehm\",\n
                                            \"ServerUrl\": \"https://www.google.com\",\n
                                            \"ServerKey\": \"sk-5f3ab4bea7cc2585091539fb950084ce\"\n}
                                            """)
        XCTAssertThrowsError(try connection.connect()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NO_CHANNELS)
        }
    }


    func testGetDeviceFingerprintHex() {
        let connection = try! connect()
        defer { try! connection.close() }
        let fp = try! connection.getDeviceFingerprintHex()
        XCTAssertEqual(fp, "3bab7ad3a583ad31b291e0c298d1e0966cba5ff31bdd422a01341c32d3894871")
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
        let connection: Connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        let fp = try! connection.getClientFingerprintHex()
        XCTAssertEqual(fp.count, 64)
    }

    func testGetClientFingerprintHexFail() {
        let client = NabtoEdgeClient()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.getClientFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testCoapRequest() {
        let connection = try! connect()
        defer { try! connection.close() }
        let coap = try! connection.createCoapRequest(method: "GET", path: "/hello-world")
        try! coap.execute()
        XCTAssertEqual(try! coap.getResponseStatusCode(), 205)
        XCTAssertEqual(try! coap.getResponseContentFormat(), 0)
        XCTAssertEqual(try! String(decoding: coap.getResponsePayload(), as: UTF8.self), "Hello world")
    }

    func testTodo() throws {
        //    throw XCTSkip("todo")
    }

}
