//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
import NabtoEdgeClient
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
    var fp: String
    var sct: String?
    var local: Bool

    init(productId: String, deviceId: String, url: String, key: String, fp: String, sct: String?=nil, local: Bool=false) {
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
            key: "sk-5f3ab4bea7cc2585091539fb950084ce",
            fp: "19ca7f85c9f4bfc47cffd8564339b897aaaef3225bde5c7b90dfff46b5eaab5b"
    )

    let tunnelDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            fp: "0b168a3b714ebe92e56b2514e5424c4c544ab760db547c34b7ff00ff90bd72cb",
            sct: "WzwjoTabnvux"
    )

    let forbiddenDevice = Device(
            productId: "pr-t4qwmuba",
            deviceId: "de-fociuotx",
            url: "https://pr-t4qwmuba.clients.nabto.net",
            key: "sk-5f3ab4bea7cc2585091539fb950084ce", // product only configured with tunnel app with sk-9c826d2ebb4343a789b280fe22b98305
            fp: "d731bc1f41deecafd8368fa865e430339148c16335c5f17d0f7e25025901e182",
            sct: "WzwjoTabnvux"
    )
    
    let passwordProtectedDevice = Device(
            productId: "pr-fatqcwj9",
            deviceId: "de-ijrdq47i",
            url: "https://pr-fatqcwj9.clients.nabto.net",
            key: "sk-9c826d2ebb4343a789b280fe22b98305",
            fp: "c25c6a3805af4d8a263541fc0ac32e5909b4cae293b85bea05d81445fed9273c",
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
            fp: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            sct: "none",
            local: true
    )

    let streamPort: UInt32 = 42

    var connection: Connection! = nil

    private var client: Client!

    override static func setUp() {
        print(Client.versionString())
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        do {
            try self.connection?.close()
        } catch (NabtoEdgeClientError.INVALID_STATE) {
            // connection probably not opened yet
        }
        assertNoLeaks(connection)
        self.connection = nil
        self.client?.stop()
        assertNoLeaks(client)
        self.client = nil
    }

    func assertNoLeaks(_ obj: AnyObject?) {
        if (obj != nil) {
            // refcount should be 3: reference from property + ref passed to this func + ref passed to CFGetRetainCount
            XCTAssertEqual(CFGetRetainCount(obj), 3)
        }

    }

    func testVersionString() throws {
        XCTAssertEqual("5.", Client.versionString().prefix(2))
    }

    func testCreateClientConnection() throws {
        self.client = Client()
        let _ = try client.createConnection()
    }

    func testDefaultLog() {
        self.client = Client()
        client.enableNsLogLogging()
        let _ = try! client.createConnection()
    }

    func testSetLogLevelValid() {
        self.client = Client()
        try! client.setLogLevel(level: "trace")
        client.enableNsLogLogging()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: self.coapDevice.asJson())
    }

    func testSetLogLevelInvalid() {
        self.client = Client()
        XCTAssertThrowsError(try client.setLogLevel(level: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCreatePrivateKey() {
        self.client = Client()
        let key = try! client.createPrivateKey()
        XCTAssertTrue(key.contains("BEGIN EC PRIVATE KEY"))
    }

    func testSetOptionsBadJson() {
        self.client = Client()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.updateOptions(json: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsInvalidParameter() {
        self.client = Client()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.updateOptions(json: "{\n\"ProductFoo\": \"...\"}")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testSetOptionsValid() {
        self.client = Client()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\",\n\"DeviceId\": \"de-12345678\",\n\"ServerUrl\": \"https://pr-12345678.clients.nabto.net\",\n\"ServerKey\": \"sk-12345678123456781234567812345678\"\n}")
    }

    func testGetOptions() {
        self.client = Client()
        let connection = try! client.createConnection()
        try! connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\"}")
        let allOptions = try! connection.getOptions()
        XCTAssertTrue(allOptions.contains("ProductId"))
        XCTAssertTrue(allOptions.contains("pr-12345678"))
    }

    func connect(_ device: Device) throws -> Connection {
        self.client = Client()
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: device.asJson())
        try self.connection.connect()
        return self.connection
    }

    func testConnect() {
        self.connection = try! connect(self.coapDevice)
    }

    func testConnectInvalidToken() {
        self.client = Client()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
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

    func testConnectAsync() {
        self.client = Client()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
        let exp = XCTestExpectation(description: "expect connect callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func testConnectAsyncFailUnknown() {
        self.client = Client()
        try! client.setLogLevel(level: "info")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
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
        self.client = Client()
        try! client.setLogLevel(level: "info")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
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
        self.client = Client()
        let connection = try! client.createConnection()
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
        self.connection = try! connect(self.coapDevice)
        let fp = try! connection.getDeviceFingerprintHex()
        XCTAssertEqual(fp, self.coapDevice.fp)
    }

    func testGetDeviceFingerprintHexFail() {
        self.client = Client()
        let connection = try! client.createConnection()
        XCTAssertThrowsError(try connection.getDeviceFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testGetClientFingerprintHex() {
        self.client = Client()
        let connection: Connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        let fp = try! connection.getClientFingerprintHex()
        XCTAssertEqual(fp.count, 64)
    }

    func testGetClientFingerprintHexFail() {
        self.client = Client()
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
            n = 1000
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
        self.client = Client()
        try! client.setLogLevel(level: "info")
        client.enableNsLogLogging()
        let scanner = client.createMdnsScanner(subType: self.mdnsSubtype)
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
            _ = try self.connect(self.forbiddenDevice)
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
    
    // [*] for some reason this simple async test with asserts in the async complete closure is completely
    // broken; failing asserts are ignored and test continues - probably something about using xctassert
    // outside the main thread (but no documentation found on the matter). Solution / work around is the
    // super ugly alternative seen in testCoapRequestAsync with asserts moved out of the closure.
    
//    func testCoapRequestAsync_Original() {
//        self.client = Client()
//        self.connection = try! client.createConnection()
//        let key = try! client.createPrivateKey()
//        try! self.connection.setPrivateKey(key: key)
//        try! self.connection.updateOptions(json: self.coapDevice.asJson())
//        let exp = XCTestExpectation(description: "expect coap done callback")
//
//        self.connection.connectAsync { ec in
//            XCTAssertEqual(ec, .OK)
//            XCTAssert(false) // <===== added to original test case ... test passes just fine with this, hence giving up
//            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
//            coap.executeAsync { ec, response in
//                XCTAssertEqual(ec, .OK)
//                XCTAssertEqual(response!.status, 205)
//                XCTAssertEqual(response!.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
//                XCTAssertEqual(String(decoding: response!.payload, as: UTF8.self), "Hello world")
//                exp.fulfill()
//            }
//        }
//
//        wait(for: [exp], timeout: 2.0)
//    }

    func testCoapRequestAsync() {
        self.client = Client()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())

        let exp1 = XCTestExpectation(description: "expect connect done callback")
        
        var ec: NabtoEdgeClientError = .FAILED
        self.connection.connectAsync { cbEc in
            ec = cbEc
            exp1.fulfill()
            // asserts do currently not work in these closures hence this ugly structure ... see [*] comment above
        }
        
        wait(for: [exp1], timeout: 2)
        XCTAssertEqual(ec, .OK)

        let exp2 = XCTestExpectation(description: "expect coap done callback")
        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        var response: CoapResponse?
        coap.executeAsync { cbEc, cbResponse in
            ec = cbEc
            response = cbResponse
            exp2.fulfill()
        }
    
        wait(for: [exp2], timeout: 2.0)
    
        XCTAssertEqual(ec, .OK)
        XCTAssertEqual(response!.status, 205)
        XCTAssertEqual(response!.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
        XCTAssertEqual(String(decoding: response!.payload, as: UTF8.self), "Hello world")
    }

    func testCoapRequestSyncAfterAsyncConnect() {
        self.client = Client()
        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: self.coapDevice.asJson())
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
        self.client = Client()
        self.connection = try! client.createConnection()
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

        wait(for: [exp], timeout: 2.0)
    }

    func testCoapRequestAsyncApiFail() {
        self.client = Client()
        self.connection = try! client.createConnection()
        let exp = XCTestExpectation(description: "expect early coap fail")

        let coap = try! self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
        coap.executeAsync { ec, response in
            exp.fulfill()
            XCTAssertEqual(ec, NabtoEdgeClientError.NOT_CONNECTED)
        }

        wait(for: [exp], timeout: 1.0)
    }

    public class TestConnectionEventCallbackReceiver : ConnectionEventReceiver {
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
        self.client = Client()
        try! client.setLogLevel(level: "info")
        client.enableNsLogLogging()
        self.connection = try! client.createConnection()
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = TestConnectionEventCallbackReceiver(exp)
        try! connection.addConnectionEventsReceiver(cb: listener)
        let key = try! client.createPrivateKey()
        try! connection.setPrivateKey(key: key)
        try! connection.updateOptions(json: self.coapDevice.asJson())
        try! connection.connect()
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)
    }

    func testStreamWriteThenReadSome() {
        let connection = try! self.connect(self.streamDevice)
        defer {
            try! connection.close()
        }
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

//    func testStreamResourceIssue() {
//        while (true) {
//           testStreamWriteThenReadSome()
//        }
//    }

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

    func testStreamWriteThenReadSomeAsync() {
        let connection = try! self.connect(self.streamDevice)
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

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
                        try connection.close()
                    } catch {
                        XCTFail("Test failed due to unexpected exception: \(error)")
                    }
                    self.client.stop()
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testStreamWriteThenReadAllAsync() {
        let connection = try! self.connect(self.streamDevice)
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

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
                    try! connection.close()
                    self.client.stop()
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testTunnelGetPortFail() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        XCTAssertThrowsError(try tunnel.getLocalPort()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testTunnelOpenClose() throws {
        try! self.connection = self.connect(self.tunnelDevice)
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

        wait(for: [exp], timeout: 3.0)
    }

    func testTunnelOpenError() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        try! self.connection = self.connect(self.tunnelDevice)
        XCTAssertThrowsError(try tunnel.open(service: "httpblab", localPort: 0)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NOT_FOUND)
        }
    }

    func testTunnelOpenCloseAsync() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        let exp = XCTestExpectation(description: "expect http request finishes")
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
        wait(for: [exp], timeout: 3.0)
    }

    func testTunnelOpenCloseAsyncSimple() throws {
        try! self.connection = self.connect(self.tunnelDevice)
        let tunnel = try! self.connection.createTcpTunnel()
        let exp = XCTestExpectation()
        tunnel.openAsync(service: "http", localPort: 0) { [weak tunnel] ec in
            XCTAssertEqual(ec, .OK)
            tunnel!.closeAsync { ec in
                XCTAssertEqual(ec, .OK)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 3.0)
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
        try! self.connection = self.connect(self.tunnelDevice)
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
        self.client = Client()
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        try! self.connection.passwordAuthenticateAsync(username: "", password: "wrong-password") { ec in
            XCTAssertEqual(ec, .UNAUTHORIZED)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testPasswordAuthAsyncOk() {
        self.client = Client()
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

        self.connection = try! client.createConnection()
        let key = try! client.createPrivateKey()
        try! self.connection.setPrivateKey(key: key)
        try! self.connection.updateOptions(json: passwordProtectedDevice.asJson())
        try! self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        try! self.connection.passwordAuthenticateAsync(username: "", password: "open-password") { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testPasswordOpenPairing() {
        self.client = Client()
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

        self.connection = try! client.createConnection()
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
        self.client = Client()
        try! self.client.setLogLevel(level: "info")
        self.client.enableNsLogLogging()

        self.connection = try! client.createConnection()
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

}
