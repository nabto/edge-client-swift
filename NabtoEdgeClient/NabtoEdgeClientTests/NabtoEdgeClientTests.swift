//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
import NabtoEdgeClient

// test org: or-3uhjvwuh
// test device source: nabto-embedded-sdk/examples/simple_coap

class Device {
    let productId: String
    let deviceId: String
    let url: String
    let key: String
    let fp: String

    init(productId: String, deviceId: String, url: String, key: String, fp: String) {
        self.productId = productId
        self.deviceId = deviceId
        self.url = url
        self.key = key
        self.fp = fp
    }
}

class NabtoEdgeClientTests: XCTestCase {

    let coapDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-avmqjaje", // in device, change from "avmqjaxe..." in public example source
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "3bab7ad3a583ad31b291e0c298d1e0966cba5ff31bdd422a01341c32d3894871"
    )

    let streamDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-bdsotcgm", // in device, change from "avmqjaxe..." in public example source
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "19ca7f85c9f4bfc47cffd8564339b897aaaef3225bde5c7b90dfff46b5eaab5b"
    )
    
    let streamPort: UInt32 = 42

    var connection: Connection! = nil

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        try connection?.close()
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

    func connect(_ device: Device) throws -> Connection {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "info")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: """
                                            {\n
                                            \"ProductId\": \"\(device.productId)\",\n
                                            \"DeviceId\": \"\(device.deviceId)\",\n
                                            \"ServerUrl\": \"\(device.url)\",\n
                                            \"ServerKey\": \"\(device.key)\"\n}
                                            """)
        try! self.connection.connect()
        return self.connection
    }

    func testConnect() {
        self.connection = try! connect(self.coapDevice)

    }

    func testConnectFail() {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        let connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: """
                                            {\n
                                            \"ProductId\": \"\(self.coapDevice.productId)\",\n
                                            \"DeviceId\": \"\(self.coapDevice.deviceId)\",\n
                                            \"ServerUrl\": \"https://www.google.com\",\n
                                            \"ServerKey\": \"\(self.coapDevice.key)\"\n}
                                            """)
        XCTAssertThrowsError(try connection.connect()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NO_CHANNELS)
        }
    }


    func testGetDeviceFingerprintHex() {
        self.connection = try! connect(self.coapDevice)
        let fp = try! connection.getDeviceFingerprintHex()
        XCTAssertEqual(fp, self.coapDevice.fp)
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


    func testTodo() throws {
//        throw XCTSkip("todo")
    }

    func testCoapRequest() {
        self.connection = try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        try! coap.execute()
        XCTAssertEqual(try! coap.getResponseStatusCode(), 205)
        XCTAssertEqual(try! coap.getResponseContentFormat(), ContentFormat.TEXT_PLAIN.rawValue)
        XCTAssertEqual(try! String(decoding: coap.getResponsePayload(), as: UTF8.self), "Hello world")
    }

    public class TestConnectionEventCallbackReceiver : ConnectionEventsCallbackReceiver {
        var events: [NabtoEdgeClientConnectionEvent] = []
        let exp: XCTestExpectation

        public init(_ exp: XCTestExpectation) {
            self.exp = exp
        }

        func onEvent(event: NabtoEdgeClientConnectionEvent) {
            events.append(event)
            exp.fulfill()
        }
    }

    func testConnectionEventListener() {
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = TestConnectionEventCallbackReceiver(exp)
        try! connection.addConnectionEventsListener(cb: listener)
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: """
                                            {\n
                                            \"ProductId\": \"\(self.coapDevice.productId)\",\n
                                            \"DeviceId\": \"\(self.coapDevice.deviceId)\",\n
                                            \"ServerUrl\": \"\(self.coapDevice.url)\",\n
                                            \"ServerKey\": \"\(self.coapDevice.key)\"\n}
                                            """)
        try! connection.connect()
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)
    }

    func testStreamWriteThenReadSome() {
        try! self.connection = self.connect(self.streamDevice)

        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        try! coap.execute()
        XCTAssertEqual(try! coap.getResponseStatusCode(), 404)

        let stream = try! self.connection.createStream()
        try! stream.open(streamPort: self.streamPort)
        let hello = "Hello"
        try! stream.write(data: hello.data(using: .utf8)!)
        let result = try! stream.readSome()
        XCTAssertGreaterThan(result.count, 0)
    }

    func testStreamWriteThenReadAll() {
        try! self.connection = self.connect(self.streamDevice)
        let stream = try! self.connection.createStream()
        try! stream.open(streamPort: self.streamPort)
        let len = 17 * 1024 + 87
        let input = String(repeating: "X", count: len)
        try! stream.write(data: input.data(using: .utf8)!)
        let result = try! stream.readAll(length: len)
        XCTAssertEqual(result.count, len)
        XCTAssertEqual(input, String(decoding: result, as: UTF8.self))
    }



}
