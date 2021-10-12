//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
@testable import NabtoEdgeClient
import Foundation
import CBOR

// test org: or-3uhjvwuh (https://console.cloud.nabto.com/#/dashboard/organizations/or-3uhjvwuh)
// test device source: nabto-embedded-sdk/examples/simple_coap
// if unauthorized errors: check auth type is set to sct in console and device sets the sct
//
// xcode does not allow running tests directly on physical iOS device; embed in a host application to do this (look for
// "Host Application" setting under the "General" tab for the test target). Note that this then fails or simulator - so
// to change back and forth between device and simulator, this option must be toggled between "None" and the host application ("HostsForTests").

struct Device {
    var productId: String
    var deviceId: String
    var url: String
    var key: String
    var fp: String?
    var sct: String?
    var local: Bool

    init(productId: String, deviceId: String, url: String, key: String, fp: String?=nil, sct: String?=nil, local: Bool=false) {
        self.productId = productId
        self.deviceId = deviceId
        self.url = url
        self.key = key
        self.fp = fp
        self.sct = sct
        self.local = local
    }

    func asJson() -> String {
        let sctElement = sct != nil ? "\"ServerConnectToken\": \"\(sct!)\",\n" : ""
        return """
               {\n
               \"Local\": \(self.local),\n
               \"ProductId\": \"\(self.productId)\",\n
               \"DeviceId\": \"\(self.deviceId)\",\n
               \"ServerUrl\": \"\(self.url)\",\n
               \(sctElement)
               \"ServerKey\": \"\(self.key)\"\n}
               """
    }
}

class NabtoEdgeClientTests: XCTestCase {

    let coapDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-avmqjaje",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "fcb78f8d53c67dbc4f72c36ca6cd2d5fc5592d584222059f0d76bdb514a9340c"
    )

    let streamDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-bdsotcgm",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce"
    )

    let tunnelDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "WzwjoTabnvux"
    )

    let forbiddenDevice = Device(
            productId: "pr-t4qwmuba",
            deviceId: "de-fociuotx",
            url: "https://pr-t4qwmuba.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce", // product only configured with tunnel app with sk-9c826d2ebb4343a789b280fe22b98305
            sct: "WzwjoTabnvux"
    )
    
    let passwordProtectedDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            sct: "WzwjoTabnvux"
    )


    // build a device for mDNS discovery testing
    //
    // $ git clone --recursive git@github.com:nabto/nabto-embedded-sdk.git
    // $ cd nabto-embedded-sdk
    // $ mkdir _build
    // $ cd _build
    // $ cmake -j ..
    //
    // run device as follows:
    //
    // $ cd _build
    // $ ./examples/simple_mdns/simple_mdns_device pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val
    static let mdnsProductId = "pr-mdns"
    static let mdnsDeviceId = "de-mdns"
    let mdnsSubtype = "swift-test-subtype"
    let mdnsTxtKey = "swift-txt-key"
    let mdnsTxtVal = "swift-txt-val"
    let mdnsDevice = Device(
            productId: "pr-mdns",
            deviceId: mdnsDeviceId,
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "none",
            sct: "none",
            local: true
    )

    let streamPort: UInt32 = 42

    var connection: Connection! = nil

    private var client: Client!

    private var clientRefCount: Int?
    private var connectionRefCount: Int?

    override func setUpWithError() throws {
        print(Client.versionString())
        setbuf(__stdoutp, nil)
        continueAfterFailure = false

        XCTAssertNil(self.client)
        self.client = Client()
        self.enableLogging(self.client)
        self.clientRefCount = CFGetRetainCount(self.client)

        XCTAssertNil(self.connection)
        self.connection = try! client.createConnection()
        self.connectionRefCount = CFGetRetainCount(self.connection)
    }

    override func tearDownWithError() throws {
        do {
            try self.connection?.close()
        } catch (NabtoEdgeClientError.ABORTED) {
            // client stopped
        } catch (NabtoEdgeClientError.INVALID_STATE) {
            // connection probably not opened yet
        }
        if (self.connection != nil) {
            XCTAssertEqual(self.connectionRefCount, CFGetRetainCount(self.connection))
            self.connection = nil
        }
        if (self.client != nil) {
            self.client.stop()
            XCTAssertEqual(self.clientRefCount, CFGetRetainCount(self.client))
            self.client = nil
        }
        XCTAssertNil(self.client)
        XCTAssertNil(self.connection)
    }

    func enableLogging(_ client: Client) {
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
    }

    func testVersionString() throws {
        XCTAssertEqual("5.", Client.versionString().prefix(2))
    }

    func testDefaultLog() {
        client.enableNsLogLogging()
        let _ = try! client.createConnection()
    }

    func testSetLogLevelValid() {
        try! connection.updateOptions(json: self.coapDevice.asJson())
    }

    func testSetLogLevelInvalid() {
        XCTAssertThrowsError(try client.setLogLevel(level: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCreatePrivateKey() {
        let key = try! client.createPrivateKey()
        XCTAssertTrue(key.contains("BEGIN EC PRIVATE KEY"))
    }

    func testSetOptionsBadJson() {
        XCTAssertThrowsError(try connection.updateOptions(json: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsInvalidParameter() {
        XCTAssertThrowsError(try connection.updateOptions(json: "{\n\"ProductFoo\": \"...\"}")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsValid() {
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\",\n\"DeviceId\": \"de-12345678\",\n\"ServerUrl\": \"https://pr-12345678.clients.nabto.net\",\n\"ServerKey\": \"sk-12345678123456781234567812345678\"\n}")
    }

    func testGetOptions() {
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\"}")
        let allOptions = try! connection.getOptions()
        XCTAssertTrue(allOptions.contains("ProductId"))
        XCTAssertTrue(allOptions.contains("pr-12345678"))
    }

    func prepareConnection(_ device: Device) {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: device.asJson())
    }

    func connect(_ device: Device) throws{
        try self.prepareConnection(device)
        try self.connection.connect()
    }

    func testConnect() {
        try! self.connect(self.coapDevice)
    }

    func testConnectInvalidToken() {
        let key = try! self.client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        var device = self.tunnelDevice
        device.sct = "invalid"
        let json = device.asJson()
        try! self.connection.updateOptions(json: json)
        let exp = XCTestExpectation(description: "error thrown")
        do {
            _ = try self.connection.connect()
        } catch NabtoEdgeClientError.NO_CHANNELS(let localError, let remoteError) {
            XCTAssertEqual(localError, .NONE)
            XCTAssertEqual(remoteError, .TOKEN_REJECTED)
            exp.fulfill()
        } catch {
            XCTFail("\(error)")
        }
        wait(for: [exp], timeout: 0.0)
    }

//    func testConnectAsync_repeated() {
//        for i in 1...1000 {
//            print("**************** iteration \(i) ****************")
//            self.testConnectAsync()
//        }
//    }

    func testConnectAsync() {
        let exp = XCTestExpectation(description: "expect connect callback")
        self.prepareConnection(self.coapDevice)
        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testConnectAsyncFailUnknown() {
        let exp = XCTestExpectation(description: "expect connect callback")
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        var device = coapDevice
        device.deviceId = "blah"
        try! self.connection.updateOptions(json: device.asJson())
        self.connection.connectAsync { ec in
            if case .NO_CHANNELS(let localError, let remoteError) = ec {
                XCTAssertEqual(localError, .NONE)
                XCTAssertEqual(remoteError, .UNKNOWN_DEVICE_ID)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testConnectAsyncFailOffline() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        var device = coapDevice
        device.deviceId = "de-jhnoa9u7"
        try! self.connection.updateOptions(json: device.asJson())
        let exp = XCTestExpectation(description: "expect connect callback")
        self.connection.connectAsync { ec in
            if case .NO_CHANNELS(let localError, let remoteError) = ec {
                XCTAssertEqual(localError, .NONE)
                XCTAssertEqual(remoteError, .NOT_ATTACHED)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testDnsFail() {
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        var device = coapDevice
        device.url = "https://nf8crjgdx7qezqkxinp8o5ex9lzjfxnr.nabto.com"
        try! connection.updateOptions(json: device.asJson())
        let exp = XCTestExpectation(description: "expect errors thrown")
        do {
            _ = try connection.connect()
        } catch NabtoEdgeClientError.NO_CHANNELS(let localError, let remoteError) {
            XCTAssertEqual(localError, .NONE)
            XCTAssertEqual(remoteError, .DNS)
            exp.fulfill()
        } catch {
            XCTFail("\(error)")
        }
        wait(for: [exp], timeout: 0)
    }

    func testGetDeviceFingerprintHex() {
        try! connect(self.coapDevice)
        let fp = try! connection.getDeviceFingerprintHex()
        XCTAssertEqual(fp, self.coapDevice.fp)
    }

    func testGetDeviceFingerprintHexFail() {
        XCTAssertThrowsError(try connection.getDeviceFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testGetClientFingerprintHex() {
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        let fp = try! connection.getClientFingerprintHex()
        XCTAssertEqual(fp.count, 64)
    }

    func testGetClientFingerprintHexFail() {
        XCTAssertThrowsError(try connection.getClientFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testCoapRequest() {
        try! self.connect(self.coapDevice)
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 205)
        XCTAssertEqual(response.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
        XCTAssertEqual(String(decoding: response.payload, as: UTF8.self), "Hello world")
    }

    public class TestMdnsResultReceiver : MdnsResultReceiver {
        var results: [MdnsResult] = []
        let exp: XCTestExpectation

        public init(_ exp: XCTestExpectation) {
            self.exp = exp
        }

        public func onResultReady(result: MdnsResult) {
            results.append(result)
            if (results.count == 1) {
                exp.fulfill()
            }
        }
    }

    // reproduce segfault
    func testCreateManyClientsWithLoggingEnabled() {
        let n: Int
        #if targetEnvironment(simulator)
        n = 100
        #else
        // each iteration takes several seconds on actual device with iOS 14.7 / Xcode 12.5.1
        n = 3
        #endif
        for _ in 1...n {
            _ = Client()
        }
    }

    // ./examples/simple_mdns/simple_mdns_device pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val
    func testMdnsDiscovery() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("mDNS forbidden on iOS 14.5+ physical device, awaiting apple app approval of container app")
//        throw XCTSkip("Needs local device for testing")
        #endif
        let scanner = self.client.createMdnsScanner(subType: self.mdnsSubtype)
        let exp = XCTestExpectation(description: "Expected to find local device for discovery, see instructions on how to run simple_mdns_device stub")
        let stub = TestMdnsResultReceiver(exp)
        scanner.addMdnsResultReceiver(stub)
        try! scanner.start()
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(stub.results.count, 1)
        XCTAssertEqual(stub.results[0].deviceId, self.mdnsDevice.deviceId)
        XCTAssertEqual(stub.results[0].productId, self.mdnsDevice.productId)
        XCTAssertEqual(stub.results[0].txtItems["nabto_version"]!.prefix(2), "5.")
        XCTAssertEqual(stub.results[0].txtItems[self.mdnsTxtKey], self.mdnsTxtVal)
        XCTAssertEqual(stub.results[0].action, .ADD)
        scanner.stop()
    }

    func testForbiddenError() {
        let exp = XCTestExpectation(description: "expect error")
        do {
            try self.connect(self.forbiddenDevice)
        } catch NabtoEdgeClientError.NO_CHANNELS(let localError, let remoteError) {
            XCTAssertEqual(localError, .NONE)
            XCTAssertEqual(remoteError, .FORBIDDEN)
            exp.fulfill()
        } catch {
            XCTFail("\(error)")
        }
        wait(for: [exp], timeout: 0.0)
    }


    func testCoapRequestInvalidMethod() {
        try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        XCTAssertThrowsError(try connection.createCoapRequest(method: "XXX", path: "/hello-world")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCoapRequest404() {
        try! self.connect(self.coapDevice)
        defer { try! self.connection.close() }
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 404)
    }
    
    func testCoapRequestAsync() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
        let expConn = XCTestExpectation(description: "expect connect done callback")
        let expCoap = XCTestExpectation(description: "expect coap done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
            coap.executeAsync { ec, response in
                XCTAssertEqual(ec, .OK)
                XCTAssertEqual(response!.status, 205)
                XCTAssertEqual(response!.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
                XCTAssertEqual(String(decoding: response!.payload, as: UTF8.self), "Hello world")
                expCoap.fulfill()
            }
            expConn.fulfill()
        }

        wait(for: [expConn, expCoap], timeout: 10.0)
    }

//    func testReproduceCrashFreeClientFromCallback_Repeated() {
//        for _ in 1...30 {
//            self.testReproduceCrashFreeClient()
//        }
//    }

    func testReproduceCrashFreeClient() {
        let exp1 = XCTestExpectation(description: "expect coap done callback")
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
        connection.connectAsync { ec in
            guard (ec == .OK) else { // odd construct to stop early as xctassert sometimes behaves weird in callbacks
                XCTFail("Connect error: \(ec)")
                return
            }
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
            coap.executeAsync { ec, response in
                guard (ec == .OK) else { // see above comment
                    XCTFail("Coap error: \(ec)")
                    return
                }
                exp1.fulfill()
            }
        }
        wait(for: [exp1], timeout: 10.0)
        client.stop()
    }


//    func testRepeat_testCoapRequestSyncAfterAsyncConnect() throws {
//        self.client = nil
//        self.connection = nil
//        for _ in 1...10 {
//            try self.setUpWithError()
//            try self.testCoapRequestAsyncAfterAsyncConnect()
//            try self.tearDownWithError()
//            XCTAssertNil(self.client)
//        }
//    }

    func testCoapRequestAsyncAfterAsyncConnect() throws {
        var conn: Connection!
        do {
            let cli = Client()
            self.enableLogging(cli)
            conn = try! cli.createConnection()
            let key = try! cli.createPrivateKey()
            try! conn.setPrivateKey(key: key)
            try! conn.updateOptions(json: self.coapDevice.asJson())
            let exp = XCTestExpectation(description: "expect coap done callback")

            conn.connectAsync(closure: { ec in
                XCTAssertEqual(ec, .OK)
                let coap = try! conn.createCoapRequest(method: "GET", path: "/hello-world")
                coap.executeAsync { ec, response in
                    XCTAssertEqual(ec, .OK)
                    XCTAssertNotNil(response)
                    XCTAssertEqual(response!.status, 205)
                    XCTAssertEqual(response!.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
                    XCTAssertEqual(String(decoding: response!.payload, as: UTF8.self), "Hello world")
                    exp.fulfill()
                }
            })
            wait(for: [exp], timeout: 10.0)
            cli.stop()
        }
        try XCTExpectFailure {
            // XXX sc-759 - currently close after client stop is ok
            XCTAssertThrowsError(try conn.close()) { error in
                XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
            }
        }
        conn = nil
    }

    func testCoapRequestAsyncCoap404() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
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

        wait(for: [exp], timeout: 10.0)
    }

    func testCoapRequestAsyncApiFail() {
        let exp = XCTestExpectation(description: "expect early coap fail")
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
        coap.executeAsync { ec, response in
            exp.fulfill()
            XCTAssertEqual(ec, NabtoEdgeClientError.NOT_CONNECTED)
        }
        wait(for: [exp], timeout: 10.0)
    }

    public class TestConnectionEventCallbackReceiver : ConnectionEventReceiver {
        var events: [NabtoEdgeClientConnectionEvent] = []
        let expConnect: XCTestExpectation
        let expClosed: XCTestExpectation

        public init(_ expConnect: XCTestExpectation, _ expClosed: XCTestExpectation) {
            self.expConnect = expConnect
            self.expClosed = expClosed
        }

        func onEvent(event: NabtoEdgeClientConnectionEvent) {
            events.append(event)
            if (event == .CONNECTED) {
                self.expConnect.fulfill()
            } else if (event == .CLOSED) {
                self.expClosed.fulfill()
            }
        }
    }

    func testConnectionEventListener() {
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = TestConnectionEventCallbackReceiver(exp, exp)
        try! self.connection.addConnectionEventsReceiver(cb: listener)
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
        try! self.connection.connect()
        wait(for: [exp], timeout: 10.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)
        self.connection.removeConnectionEventsReceiver(cb: listener)
    }

    func testConnectionEventListenerMultipleEvents() {
        let expConnect = XCTestExpectation(description: "expect connect event callback")
        let expClosed = XCTestExpectation(description: "expect close event callback")
        let listener = TestConnectionEventCallbackReceiver(expConnect, expClosed)
        try! connection.addConnectionEventsReceiver(cb: listener)
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: self.coapDevice.asJson())

        try! connection.connect()
        wait(for: [expConnect], timeout: 10.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)

        try! connection.close()
        wait(for: [expClosed], timeout: 10.0)
        XCTAssertEqual(listener.events.count, 2)
        XCTAssertEqual(listener.events[0], .CONNECTED)
        XCTAssertEqual(listener.events[1], .CLOSED)

        self.connection = nil // prevent extra close in teardown
    }

    public class CrashInducingConnectionEventCallbackReceiver : ConnectionEventReceiver {
        let exp: XCTestExpectation
        weak var connection: Connection?

        public init(_ exp: XCTestExpectation, _ connection: Connection) {
            self.exp = exp
            self.connection = connection
        }

        func onEvent(event: NabtoEdgeClientConnectionEvent) {
            if let c = self.connection {
                c.removeConnectionEventsReceiver(cb: self)
            } else {
                XCTFail("connection gone")
            }
            self.exp.fulfill()
        }
    }

    func testRemoveConnectionEventListenerFromCallback() {
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = CrashInducingConnectionEventCallbackReceiver(exp, self.connection)
        try! self.connection.addConnectionEventsReceiver(cb: listener)
        XCTAssertNotNil(self.connection.connectionEventListener)
        XCTAssertTrue(self.connection.connectionEventListener!.hasUserCbs())
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
        try! self.connection.connect()
        wait(for: [exp], timeout: 10.0)
        XCTAssertNil(self.connection.connectionEventListener)
    }


    func testStreamWriteThenReadSome() {
        try! self.connect(self.streamDevice)
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 404)

        let stream = try! self.connection.createStream()
        defer {
            try! stream.close()
        }
        try! stream.open(streamPort: self.streamPort)
        let hello = "Hello"
        try! stream.write(data: hello.data(using: .utf8)!)
        let result = try! stream.readSome()
        XCTAssertGreaterThan(result.count, 0)
    }

    func testStreamWriteThenReadAll() {
        try! self.connect(self.streamDevice)
        let stream = try! self.connection.createStream()
        defer {
            try! stream.close()
        }
        try! stream.open(streamPort: self.streamPort)
        let len = 17 * 1024 + 87
        let input = String(repeating: "X", count: len)
        try! stream.write(data: input.data(using: .utf8)!)
        let result = try! stream.readAll(length: len)
        XCTAssertEqual(result.count, len)
        XCTAssertEqual(input, String(decoding: result, as: UTF8.self))
    }

    func testStreamUseAfterClientStop() {
        try! self.connect(self.streamDevice)
        let stream = try! self.connection.createStream()
        try! stream.open(streamPort: self.streamPort)
        let len = 17 * 1024 + 87
        let input = String(repeating: "X", count: len)
        try! stream.write(data: input.data(using: .utf8)!)
        self.client.stop()
        XCTAssertThrowsError(try stream.readAll(length: len)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
        }
        self.client = nil
    }

    // awaiting conclusion on sc-752
//    func testStreamUseAfterConnectionClose() {
//        try! self.connect(self.streamDevice)
//        let stream = try! self.connection.createStream()
//        try! stream.open(streamPort: self.streamPort)
//        let len = 17 * 1024 + 87
//        let input = String(repeating: "X", count: len)
//        try! stream.write(data: input.data(using: .utf8)!)
//        try! self.connection.close()
//        XCTAssertThrowsError(try stream.readAll(length: len)) { error in
//            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
//        }
//    }

    func testStreamWriteThenReadSomeAsync() {
        try! self.connect(self.streamDevice)
        let stream = try! self.connection.createStream()
        let exp = XCTestExpectation(description: "expect stream echo data read")
        stream.openAsync(streamPort: self.streamPort) { ec in
            let hello = "Hello"
            stream.writeAsync(data: hello.data(using: .utf8)!) { ec in
                stream.readSomeAsync { ec, data in
                    XCTAssertEqual(ec, .OK)
                    XCTAssertGreaterThan(data!.count, 0)
                    XCTAssertEqual(hello, String(decoding: data!, as: UTF8.self))
                    do {
                        try stream.close()
                    } catch {
                        XCTFail("Test failed due to unexpected exception: \(error)")
                    }
                    self.client.stop()
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testStreamWriteThenReadAllAsync() {
        try! self.connect(self.streamDevice)
        let stream = try! self.connection.createStream()
        let exp = XCTestExpectation(description: "expect stream echo data read")
        stream.openAsync(streamPort: self.streamPort) { ec in
            let len = 17 * 1024 + 87
            let input = String(repeating: "X", count: len)
            stream.writeAsync(data: input.data(using: .utf8)!) { ec in
                stream.readAllAsync(length: len) { ec, data in
                    XCTAssertEqual(ec, .OK)
                    XCTAssertGreaterThan(data!.count, 0)
                    XCTAssertEqual(input, String(decoding: data!, as: UTF8.self))
                    try! stream.close()
                    try! self.connection.close()
                    self.client.stop()
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testTunnelGetPortFail() throws {
        try! self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        XCTAssertThrowsError(try tunnel.getLocalPort()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testTunnelOpenClose() throws {
        try! self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        try tunnel.open(service: "http", localPort: 0)
        let port = try! tunnel.getLocalPort()
        XCTAssertGreaterThan(port, 0)

        // http client caches results pr default
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil;

        let exp = XCTestExpectation(description: "expect http request finishes")
        let urlSession1 = URLSession(configuration: config)
        urlSession1.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) {(data, response, error) in
            XCTAssertNil(error)
            let body = String(data: data!, encoding: String.Encoding.utf8) ?? ""
            XCTAssertTrue(body.contains("html"))

            try! tunnel.close()
            let urlSession2 = URLSession(configuration: config)
            urlSession2.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) {(data, response, error) in
                XCTAssertNotNil(error)
                exp.fulfill()
            }.resume()

        }.resume()

        wait(for: [exp], timeout: 10.0)
    }

    func testTunnelOpenInvalidService() throws {
        try! self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        XCTAssertThrowsError(try tunnel.open(service: "httpblab", localPort: 0)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NOT_FOUND)
        }
    }

    func testTunnelOpenAfterClientStop() throws {
//        try! self.connect(self.tunnelDevice)
//        let tunnel = try! self.connection.createTcpTunnel()
//        self.client.stop()
//        let t = try tunnel.open(service: "httpblab", localPort: 0)
//        XCTAssertThrowsError(try tunnel.open(service: "httpblab", localPort: 0)) { error in
//            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
//        }
//        self.client = nil
    }


//    func testTunnelOpenCloseAsync_repeated() {
//        for i in 1...1_000_000_000 {
//            print("**************** iteration \(i) ****************")
//            try! self.testTunnelOpenCloseAsync()
//            try! self.tearDownWithError()
//        }
//    }

    func testTunnelOpenCloseAsync() throws {
        try! self.connect(self.tunnelDevice)

//        let connection = try! client.createConnection()
//        let key = try! client.createPrivateKey()
//        try connection.setPrivateKey(key: key)
//        try connection.updateOptions(json: self.tunnelDevice.asJson())
//        try connection.connect()

        let tunnel = try! connection.createTcpTunnel()
        let exp = XCTestExpectation(description: "expect http request finishes")
        tunnel.openAsync(service: "http", localPort: 0) { [weak tunnel] ec in
            XCTAssertEqual(ec, .OK)
            let port = try! tunnel!.getLocalPort()
            XCTAssertGreaterThan(port, 0)

            // http client caches results per default
            let config = URLSessionConfiguration.ephemeral
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil;

            let urlSession1 = URLSession(configuration: config)

            urlSession1.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) { [weak tunnel] (data, response, error) in
                XCTAssertNil(error)
                let body = String(data: data!, encoding: String.Encoding.utf8) ?? ""
                XCTAssertTrue(body.contains("html"))

                tunnel?.closeAsync { ec in
                    XCTAssertEqual(ec, .OK)
                    let urlSession2 = URLSession(configuration: config)
                    urlSession2.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) { (data, response, error) in
                        XCTAssertNotNil(error)
                        exp.fulfill()
                    }.resume()
                }
            }.resume()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testTunnelOpenCloseAsyncSimple() throws {
        try! self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        let exp = XCTestExpectation()
        tunnel.openAsync(service: "http", localPort: 0) { [weak tunnel] ec in
            XCTAssertEqual(ec, .OK)
            tunnel!.closeAsync { ec in
                XCTAssertEqual(ec, .OK)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    class K1 {
        var other: K2?
        init() {
            NSLog("K1 init")
        }
        deinit {
            NSLog("K1 deinit")
        }
    }
    
    class K2 {
        var other: K1?
        init() {
            NSLog("K2 init")
        }
        deinit {
            NSLog("K2 deinit")
        }
    }

    func testLeakDetectionTools() {
        let k1 = K1()
        let k2 = K2()
        k1.other = k2
        k2.other = k1
        NSLog("we just leaked")
    }
    
    func testTunnelOpenCloseAsyncSomewhatSimple() throws {
        try! self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        let exp1 = XCTestExpectation(description: "expect tunnel open done")
        let exp2 = XCTestExpectation(description: "expect tunnel closed done")
        tunnel.openAsync(service: "http", localPort: 0) { [weak tunnel] ec in
            XCTAssertEqual(ec, .OK)
            let port = try! tunnel!.getLocalPort()
            XCTAssertGreaterThan(port, 0)

            // http client caches results pr default
            let config = URLSessionConfiguration.ephemeral
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil;

            let urlSession1 = URLSession(configuration: config)

            urlSession1.dataTask(with: URL(string: "http://127.0.0.1:\(port)/")!) { [weak tunnel] (data, response, error) in
                XCTAssertNil(error)
                let body = String(data: data!, encoding: String.Encoding.utf8) ?? ""
                XCTAssertTrue(body.contains("html"))

                tunnel!.closeAsync { ec in
                    XCTAssertEqual(ec, .OK)
                    exp2.fulfill()
                }
            }.resume()

            exp1.fulfill()
        }
        wait(for: [exp1, exp2], timeout: 10.0)
    }

    func testPasswordAuthAsyncFail() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        try! self.connection.passwordAuthenticateAsync(username: "", password: "wrong-password") { ec in
            XCTAssertEqual(ec, .UNAUTHORIZED)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testPasswordAuthAsyncOk() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        try! self.connection.passwordAuthenticateAsync(username: "", password: "open-password") { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30.0)
    }

    func testPasswordOpenPairing() {
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        try! self.connection.passwordAuthenticate(username: "", password: "open-password")

        let coap = try! self.connection.createCoapRequest(method: "POST", path: "/iam/pairing/password-open")
        let json: [String:String] = ["Username": UUID().uuidString.lowercased()]
        let cbor = CBOR.encode(json)
        try! coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: Data(cbor))
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 201)
        XCTAssertEqual(response.contentFormat, nil)
        XCTAssertEqual(response.payload, nil)

        // in an actual pairing use case, now persist device's fingerprint (obtained with connection.getDeviceFingerprintHex())
        // along with device id etc and compare at subsequent connection attempt
    }

    func testPasswordInvitePairing() throws {
        throw XCTSkip("An invitation only works for a single pairing so this test needs clearing device state")
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        try! self.connection.passwordAuthenticate(username: "admin", password: "admin-password")

        let coap = try! self.connection.createCoapRequest(method: "POST", path: "/iam/pairing/password-invite")
        let response = try! coap.execute()
        XCTAssertEqual(response.status, 201)
        XCTAssertEqual(response.contentFormat, nil)
        XCTAssertEqual(response.payload, nil)

        // in an actual pairing use case, now persist device's fingerprint (obtained with connection.getDeviceFingerprintHex())
        // along with device id etc and compare at subsequent connection attempt
    }

    func testGracefullyHandleConnectionLivesLongerThanClient() throws {
        // clean up test objects created in setup to not confuse log output
        try self.tearDownWithError()

        var cli: Client! = Client()
        self.enableLogging(cli)
        var conn: Connection! = try! cli.createConnection()
        let key = try! cli.createPrivateKey()
        try! conn.setPrivateKey(key: key)
        try! conn.updateOptions(json: self.coapDevice.asJson())

        try! conn.connect()
        cli.stop()
        cli = nil

        // Nabto Client SDK currently returns OK after client stop, await sc-759 fix
        try XCTExpectFailure {
            XCTAssertThrowsError(try conn.createCoapRequest(method: "GET", path: "/foo")) { error in
                XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
            }
            XCTAssertThrowsError(try conn.close()) { error in
                XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
            }
        }
    }

    func testAsyncConnectionCloseAfterClientStop() throws {
        // clean up test objects created in setup to not confuse log output
        try self.tearDownWithError()

        var conn: Connection!
        do {
            let cli = Client()
            self.enableLogging(cli)
            conn = try! cli.createConnection()
            let key = try! cli.createPrivateKey()
            try! conn.setPrivateKey(key: key)
            try! conn.updateOptions(json: self.coapDevice.asJson())
            try! conn.connect()
        }

        let exp = XCTestExpectation(description: "close done - remove when sc-759 is fixed")

        XCTExpectFailure {
            // Nabto Client SDK currently allows starting new async operations after client stop, await sc-759 fix
            XCTAssertThrowsError(conn.closeAsync { ec in
                exp.fulfill()
            }) { error in
                XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
            }
        }

        wait(for: [exp], timeout: 10)
    }
}
