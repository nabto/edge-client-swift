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
            deviceId: "de-bdsotcgm",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "19ca7f85c9f4bfc47cffd8564339b897aaaef3225bde5c7b90dfff46b5eaab5b"
    )

    let tunnelDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "0b168a3b714ebe92e56b2514e5424c4c544ab760db547c34b7ff00ff90bd72cb"
    )

    let streamPort: UInt32 = 42

    var connection: Connection! = nil

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        do {
            try connection?.close()
        } catch (NabtoEdgeClientError.INVALID_STATE) {
            // connection probably not opened yet
        }
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

    func testConnectAsync() {
        let device = coapDevice
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
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
        let exp = XCTestExpectation(description: "expect connect callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testConnectAsyncFail() {
        let device = coapDevice
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: """
                                                 {\n
                                                 \"ProductId\": \"non-existing",\n
                                                 \"DeviceId\": \"blah\",\n
                                                 \"ServerUrl\": \"\(device.url)\",\n
                                                 \"ServerKey\": \"\(device.key)\"\n}
                                                 """)
        let exp = XCTestExpectation(description: "expect connect callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .NO_CHANNELS)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
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
        // reproduce OC-20532
//        throw XCTSkip("todo")
    }

    func testCoapRequest() {
        self.connection = try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 205)
        XCTAssertEqual(response.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
        XCTAssertEqual(String(decoding: response.payload, as: UTF8.self), "Hello world")
    }

    func testCoapRequestInvalidMethod() {
        self.connection = try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        XCTAssertThrowsError(try connection.createCoapRequest(method: "XXX", path: "/hello-world")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCoapRequest404() {
        self.connection = try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 404)
    }


    func testCoapRequestAsync() {
        let device = coapDevice
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
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
        let exp = XCTestExpectation(description: "expect coap done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
            coap.executeAsync { ec, response in
                XCTAssertEqual(response!.status, 205)
                XCTAssertEqual(response!.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
                XCTAssertEqual(String(decoding: response!.payload, as: UTF8.self), "Hello world")
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testCoapRequestSyncAfterAsyncConnect() {
        let device = coapDevice
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
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
        let exp = XCTestExpectation(description: "expect coap done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
            let response = try! coap.execute()
            XCTAssertEqual(response.status, 205)
            XCTAssertEqual(response.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
            XCTAssertEqual(String(decoding: response.payload, as: UTF8.self), "Hello world")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testCoapRequestAsyncCoap404() {
        let device = coapDevice
        let client = NabtoEdgeClient()
        try! client.setLogLevel(level: "trace")
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
        let exp = XCTestExpectation(description: "expect coap done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
            coap.executeAsync { ec, response in
                XCTAssertEqual(ec, .OK)
                XCTAssertEqual(response!.status, 404)
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 2.0)
    }

    // slow test due to timeout being only error to test - so skip until nabto-2245 is fixed (or another way of testing api fail is discovered)
//    func testCoapRequestAsyncApiFail() {
//        let device = coapDevice
//        let client = NabtoEdgeClient()
//        try! client.setLogLevel(level: "trace")
//        client.enableNsLogLogging()
//        self.connection = try! client.createConnection()
//        let exp = XCTestExpectation(description: "expect early coap fail")
//
//        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
//        coap.executeAsync { ec, response in
//            exp.fulfill()
//            XCTAssertEqual(ec, NabtoEdgeClientError.TIMEOUT)
//        }
//
//        wait(for: [exp], timeout: 12.0)
//    }





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
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 404)

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

    // skipped due to NABTO-2228
    func testTunnelGetPortFail() throws {
        // commented out due to OC-20532
//        throw XCTSkip("Nabto-2228")
//        try! self.connection = self.connect(self.tunnelDevice)
//        let tunnel = try! self.connection.createTcpTunnel()
//        XCTAssertThrowsError(try! tunnel.getLocalPort()) { error in
//            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
//        }
    }

    func testTunnelOpenClose() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        try tunnel.open(service: "http", localPort: 0)
        let port = try! tunnel.getLocalPort()
        XCTAssertGreaterThan(port, 0)

        let exp = XCTestExpectation(description: "expect http request finishes")
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) {(data, response, error) in
            let body = String(data: data!, encoding: String.Encoding.utf8) ?? ""
            XCTAssertTrue(body.contains("Debian"))
            exp.fulfill()

            // nabto_client_tcp_tunnel_close does not work (NABTO-2234)
//            try! tunnel.close()
//            URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) {(data, response, error) in
//                let body = String(data: data!, encoding: String.Encoding.utf8) ?? ""
//                XCTAssertFalse(body.contains("Debian"))
//                exp.fulfill()
//            }.resume()

        }.resume()

        wait(for: [exp], timeout: 2.0)
    }

    func testTunnelOpenError() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        try! self.connection = self.connect(self.tunnelDevice)
        XCTAssertThrowsError(try tunnel.open(service: "httpblab", localPort: 0)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NOT_FOUND)
        }
    }

}
