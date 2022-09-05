//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
@testable import NabtoEdgeClient

//import NabtoClient
import Foundation

// test org: or-3uhjvwuh (https://console.cloud.nabto.com/#/dashboard/organizations/or-3uhjvwuh)
// test device source: nabto-embedded-sdk/examples/simple_coap
// if unauthorized errors: check auth type is set to sct in console and device sets the sct
//
// xcode does not allow running tests directly on physical iOS device; embed in a host application to do this (look for
// "Host Application" setting under the "General" tab for the test target). Note that this then fails or simulator - so
// to change back and forth between device and simulator, this option must be toggled between "None" and the host application ("HostsForTests").


class NabtoEdgeClientTestBase: XCTestCase {
    let testDevices = TestDevices()
    var connection: Connection! = nil
    var client: Client!
    var clientRefCount: Int?
    var connectionRefCount: Int?
    let streamPort: UInt32 = 42

    func uniqueUser() -> String {
        String(UUID().uuidString.lowercased().prefix(16))
    }

    override func setUpWithError() throws {
        print(Client.versionString())
        setbuf(__stdoutp, nil)
        continueAfterFailure = false

        XCTAssertNil(self.client)
        self.client = Client()
        try self.enableLogging(self.client)
        self.clientRefCount = CFGetRetainCount(self.client)

        XCTAssertNil(self.connection)
        self.connection = try client.createConnection()
        self.connectionRefCount = CFGetRetainCount(self.connection)
    }

    override func tearDownWithError() throws {
        do {
            try self.connection?.close()
        } catch (NabtoEdgeClientError.STOPPED) {
            // client stopped
        } catch (NabtoEdgeClientError.NOT_CONNECTED) {
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

    func enableLogging(_ client: Client) throws {
        try client.setLogLevel(level: "info")
        client.enableNsLogLogging()
    }

    func prepareConnection(_ device: TestDevice) throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: device.asJson())
    }

    func connect(_ device: TestDevice) throws{
        try self.prepareConnection(device)
        try self.connection.connect()
    }
}

class NabtoEdgeClientTests: NabtoEdgeClientTestBase {

    func testVersionString() throws {
        let prefix = Client.versionString().prefix(2)
        let isBranch = prefix == "5."
        let isMaster = prefix == "0."
        XCTAssertTrue(isBranch || isMaster, "version prefix: \(prefix)")
    }

    func testDefaultLog() throws {
        client.enableNsLogLogging()
        let _ = try client.createConnection()
    }

    func testSetLogLevelValid() throws {
        try connection.updateOptions(json: self.testDevices.coapDevice.asJson())
    }

    func testSetLogLevelInvalid() {
        XCTAssertThrowsError(try client.setLogLevel(level: "foo")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCreatePrivateKey() throws {
        let key = try client.createPrivateKey()
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

    func testSetOptionsValid() throws {
        try connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\",\n\"DeviceId\": \"de-12345678\",\n\"ServerUrl\": \"https://pr-12345678.clients.nabto.net\",\n\"ServerKey\": \"sk-12345678123456781234567812345678\"\n}")
    }

    func testGetOptions() throws {
        try connection.updateOptions(json: "{\n\"ProductId\": \"pr-12345678\"}")
        let allOptions = try connection.getOptions()
        XCTAssertTrue(allOptions.contains("ProductId"))
        XCTAssertTrue(allOptions.contains("pr-12345678"))
    }

    func testConnect() throws {
        try self.connect(self.testDevices.coapDevice)
    }

    func testConnectInvalidToken() throws {
        let key = try self.client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        var device = self.testDevices.tunnelDevice
        device.sct = "invalid"
        let json = device.asJson()
        try self.connection.updateOptions(json: json)
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

    func testConnectAsync() throws {
        let exp = XCTestExpectation(description: "expect connect callback")
        try self.prepareConnection(self.testDevices.coapDevice)
        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testConnectAsyncFailUnknown() throws {
        let exp = XCTestExpectation(description: "expect connect callback")
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        var device = self.testDevices.coapDevice
        device.deviceId = "blah"
        try self.connection.updateOptions(json: device.asJson())
        self.connection.connectAsync { ec in
            if case .NO_CHANNELS(let localError, let remoteError) = ec {
                XCTAssertEqual(localError, .NONE)
                XCTAssertEqual(remoteError, .UNKNOWN_DEVICE_ID)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testConnectAsyncFailOffline() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        var device = self.testDevices.offlineDevice
        try self.connection.updateOptions(json: device.asJson())
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

    func testDnsFail() throws {
        let key = try client.createPrivateKey()
        try connection.setPrivateKey(key: key)
        var device = self.testDevices.coapDevice
        device.url = "https://nf8crjgdx7qezqkxinp8o5ex9lzjfxnr.nabto.com"
        try connection.updateOptions(json: device.asJson())
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

    func testGetDeviceFingerprintHex() throws {
        try connect(self.testDevices.coapDevice)
        let fp = try connection.getDeviceFingerprintHex()
        XCTAssertEqual(fp, self.testDevices.coapDevice.fp)
    }

    func testGetDeviceFingerprintHexFail() {
        XCTAssertThrowsError(try connection.getDeviceFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NOT_CONNECTED)
        }
    }

    func testGetClientFingerprintHex() throws {
        let key = try client.createPrivateKey()
        try connection.setPrivateKey(key: key)
        let fp = try connection.getClientFingerprintHex()
        XCTAssertEqual(fp.count, 64)
    }

    func testGetClientFingerprintHexFail() {
        XCTAssertThrowsError(try connection.getClientFingerprintHex()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testCoapRequest() throws {
        try self.connect(self.testDevices.coapDevice)
        let coap = try self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try coap.execute()
        XCTAssertEqual(response.status, 205)
        XCTAssertEqual(response.contentFormat, ContentFormat.TEXT_PLAIN.rawValue)
        XCTAssertEqual(String(decoding: response.payload, as: UTF8.self), "Hello world")
    }

    public class BlockingMdnsResultReceiver : MdnsResultReceiver {
        let exp: XCTestExpectation
        let waiter: XCTestCase

        public func onResultReady(result: MdnsResult) {
            waiter.wait(for: [self.exp], timeout: 10.0)
        }

        public init(_ exp: XCTestExpectation, _ waiter: XCTestCase) {
            self.exp = exp
            self.waiter = waiter
        }
    }

    public class TestMdnsResultReceiver : MdnsResultReceiver {
        var results: [MdnsResult] = []
        let exp: XCTestExpectation

        public init(_ exp: XCTestExpectation) {
            self.exp = exp
        }

        let dummy = MdnsResult(serviceInstanceName: "test-serviceInstanceName", action: .ADD, deviceId: "test-deviceId", productId: nil, txtItems: nil)

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
//        throw XCTSkip("Needs local device for testing")
        #if !targetEnvironment(simulator)
        throw XCTSkip("mDNS forbidden on iOS 14.5+ physical device, awaiting apple app approval of container app")
        #endif
        let scanner = self.client.createMdnsScanner(subType: self.testDevices.mdnsSubtype)
        let exp = XCTestExpectation(description: "Expected to find local device for discovery, see instructions on how to run simple_mdns_device stub")
        let stub = TestMdnsResultReceiver(exp)
        scanner.addMdnsResultReceiver(stub)
        try scanner.start()
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(stub.results.count, 1)
        XCTAssertEqual(stub.results[0].deviceId, self.testDevices.localMdnsDevice.deviceId)
        XCTAssertEqual(stub.results[0].productId, self.testDevices.localMdnsDevice.productId)
        let versionPrefix = stub.results[0].txtItems["nabto_version"]!.prefix(2)
        XCTAssertTrue(versionPrefix == "5." || versionPrefix == "0.")
        XCTAssertEqual(stub.results[0].txtItems[self.testDevices.mdnsTxtKey], self.testDevices.mdnsTxtVal)
        XCTAssertEqual(stub.results[0].action, .ADD)
        scanner.stop()
    }

    func testReproduceMdnsCrash() throws {
        let exp = XCTestExpectation(description: "dummy")
        let stub = BlockingMdnsResultReceiver(exp, self)

        let scanner1 = self.client.createMdnsScanner(subType: self.testDevices.mdnsSubtype)
        scanner1.addMdnsResultReceiver(stub)
        try scanner1.start()

        // allow some time to discover a device then stop scanner before callback is done
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            try! scanner1.stop()

            // callback completes after stop - allow time to reset listener
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                exp.fulfill()
            }
        }

        // wait a bit to make sure listener is attempted to be armed (crash occurs)
        let exp2 = XCTestExpectation(description: "dummy")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 0.5)
    }

    func testForbiddenError() {
        let exp = XCTestExpectation(description: "expect error")
        do {
            try self.connect(self.testDevices.forbiddenDevice)
        } catch NabtoEdgeClientError.NO_CHANNELS(let localError, let remoteError) {
            XCTAssertEqual(localError, .NONE)
            XCTAssertEqual(remoteError, .FORBIDDEN)
            exp.fulfill()
        } catch {
            XCTFail("\(error)")
        }
        wait(for: [exp], timeout: 0.0)
    }


    func testCoapRequestInvalidMethod() throws {
        try self.connect(self.testDevices.coapDevice)
        defer { try! self.connection.close() }
        XCTAssertThrowsError(try connection.createCoapRequest(method: "XXX", path: "/hello-world")) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_ARGUMENT)
        }
    }

    func testCoapRequest404() throws {
        try self.connect(self.testDevices.coapDevice)
        defer { try! self.connection.close() }
        let coap = try self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
        let response = try coap.execute()
        XCTAssertEqual(response.status, 404)
    }
    
    func testCoapRequestAsync() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: self.testDevices.coapDevice.asJson())
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

    // XXX: poor test - expect random failures
    func testStopAsyncConnect() throws {
        try self.prepareConnection(self.testDevices.coapDevice)
        let expConn = XCTestExpectation(description: "expect connect done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .STOPPED)
            expConn.fulfill()
        }

        // poor test... depends on the following being executed before connection is complete
        self.connection.stop()

        wait(for: [expConn], timeout: 10.0)
    }

    // XXX: poor test - expect random failures
    func testStopAsyncCoapRequest() throws {
        try self.prepareConnection(self.testDevices.coapDevice)
        let expConn = XCTestExpectation(description: "expect connect done callback")
        let expCoap = XCTestExpectation(description: "expect coap done callback")

        self.connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! self.connection.createCoapRequest(method: "GET", path: "/hello-world")
            coap.executeAsync { ec, response in
                XCTAssertEqual(ec, .STOPPED)
                expCoap.fulfill()
            }
            // poor test... depends on the following being executed before coap execution is complete
            coap.stop()
            expConn.fulfill()
        }

        wait(for: [expConn, expCoap], timeout: 10.0)
    }


//    func testReproduceCrashFreeClientFromCallback_Repeated() {
//        for _ in 1...30 {
//            self.testReproduceCrashFreeClient()
//        }
//    }

    func testReproduceCrashFreeClient() throws {
        let exp1 = XCTestExpectation(description: "expect coap done callback")
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: self.testDevices.coapDevice.asJson())
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
            try self.enableLogging(cli)
            conn = try cli.createConnection()
            let key = try cli.createPrivateKey()
            try conn.setPrivateKey(key: key)
            try conn.updateOptions(json: self.testDevices.coapDevice.asJson())
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
        XCTAssertThrowsError(try conn.close()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.STOPPED)
        }
        conn = nil
    }

    func testCoapRequestAsyncCoap404() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: self.testDevices.coapDevice.asJson())
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

    // see comment below regarding #828 and #834
    func testDoubleClose_Repeated() throws {
        for i in 1...10 {
            print(" === iteration \(i) ==================================================")
            try self.testDoubleClose()
        }
    }

    // this function was the one invoked in tickets #828 and #834 - but the test is bad: exp fulfilled in wrong place
    func testDoubleClose_crash() throws {
        let client = Client()
        try self.enableLogging(client)
        let connection = try client.createConnection()
        let key = try client.createPrivateKey()
        try connection.setPrivateKey(key: key)
        try connection.updateOptions(json: self.testDevices.coapDevice.asJson())
        let exp = XCTestExpectation(description: "expect coap done callback")

        connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
            coap.executeAsync { ec, response in
                XCTAssertEqual(ec, .OK)
                XCTAssertEqual(response!.status, 404)
                connection.closeAsync { ec in
                    connection.closeAsync { ec in
                        XCTAssertEqual(ec, .STOPPED)
                    }
                }
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 10.0)
    }

    // see comment above regarding #828 and #834
    func testDoubleClose() throws {
        let client = Client()
        try self.enableLogging(client)
        let connection = try client.createConnection()
        let key = try client.createPrivateKey()
        try connection.setPrivateKey(key: key)
        try connection.updateOptions(json: self.testDevices.coapDevice.asJson())
        let exp = XCTestExpectation(description: "expect coap done callback")

        connection.connectAsync { ec in
            XCTAssertEqual(ec, .OK)
            let coap = try! connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
            coap.executeAsync { ec, response in
                XCTAssertEqual(ec, .OK)
                XCTAssertEqual(response!.status, 404)
                connection.closeAsync { ec in
                    connection.closeAsync { ec in
                        XCTAssertEqual(ec, .STOPPED)
                        exp.fulfill()
                    }
                }
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testCoapRequestAsyncApiFail() throws {
        let exp = XCTestExpectation(description: "expect early coap fail")
        let coap = try self.connection.createCoapRequest(method: "GET", path: "/does-not-exist-trigger-404")
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

    func testConnectionEventListener() throws {
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = TestConnectionEventCallbackReceiver(exp, exp)
        try self.connection.addConnectionEventsReceiver(cb: listener)
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: self.testDevices.coapDevice.asJson())
        try self.connection.connect()
        wait(for: [exp], timeout: 10.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)
        self.connection.removeConnectionEventsReceiver(cb: listener)
    }

    func testConnectionEventListenerMultipleEvents() throws {
        let expConnect = XCTestExpectation(description: "expect connect event callback")
        let expClosed = XCTestExpectation(description: "expect close event callback")
        let listener = TestConnectionEventCallbackReceiver(expConnect, expClosed)
        try connection.addConnectionEventsReceiver(cb: listener)
        let key = try client.createPrivateKey()
        try connection.setPrivateKey(key: key)
        try connection.updateOptions(json: self.testDevices.coapDevice.asJson())

        try connection.connect()
        wait(for: [expConnect], timeout: 10.0)
        XCTAssertEqual(listener.events.count, 1)
        XCTAssertEqual(listener.events[0], .CONNECTED)

        try connection.close()
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

    func testRemoveConnectionEventListenerFromCallback() throws {
        let exp = XCTestExpectation(description: "expect event callback")
        let listener = CrashInducingConnectionEventCallbackReceiver(exp, self.connection)
        try self.connection.addConnectionEventsReceiver(cb: listener)
        XCTAssertNotNil(self.connection.connectionEventListener)
        XCTAssertTrue(self.connection.connectionEventListener!.hasUserCbs())
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: self.testDevices.coapDevice.asJson())
        try self.connection.connect()
        wait(for: [exp], timeout: 10.0)
        XCTAssertNil(self.connection.connectionEventListener)
    }


    func testStreamWriteThenReadSome() throws {
        try self.connect(self.testDevices.streamDevice)
        let coap = try self.connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try coap.execute()
        XCTAssertEqual(response.status, 404)

        let stream = try self.connection.createStream()
        defer {
            try! stream.close()
        }
        try stream.open(streamPort: self.streamPort)
        let hello = "Hello"
        try stream.write(data: hello.data(using: .utf8)!)
        let result = try stream.readSome()
        XCTAssertGreaterThan(result.count, 0)
    }

    func testStreamWriteThenReadAll() throws {
        try self.connect(self.testDevices.streamDevice)
        let stream = try self.connection.createStream()
        defer {
            try! stream.close()
        }
        try stream.open(streamPort: self.streamPort)
        let len = 17 * 1024 + 87
        let input = String(repeating: "X", count: len)
        try stream.write(data: input.data(using: .utf8)!)
        let result = try stream.readAll(length: len)
        XCTAssertEqual(result.count, len)
        XCTAssertEqual(input, String(decoding: result, as: UTF8.self))
    }

    func testStreamUseAfterClientStop() throws {
        try self.connect(self.testDevices.streamDevice)
        let stream = try self.connection.createStream()
        try stream.open(streamPort: self.streamPort)
        let len = 17 * 1024 + 87
        let input = String(repeating: "X", count: len)
        try stream.write(data: input.data(using: .utf8)!)
        self.client.stop()
        XCTAssertThrowsError(try stream.readAll(length: len)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.STOPPED)
        }
        self.client = nil
    }

    // awaiting conclusion on sc-752
//    func testStreamUseAfterConnectionClose() {
//        try self.connect(self.streamDevice)
//        let stream = try self.connection.createStream()
//        try stream.open(streamPort: self.streamPort)
//        let len = 17 * 1024 + 87
//        let input = String(repeating: "X", count: len)
//        try stream.write(data: input.data(using: .utf8)!)
//        try self.connection.close()
//        XCTAssertThrowsError(try stream.readAll(length: len)) { error in
//            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.ABORTED)
//        }
//    }

    func testStreamWriteThenReadSomeAsync() throws {
        try self.connect(self.testDevices.streamDevice)
        let stream = try self.connection.createStream()
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
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testStreamWriteThenReadAllAsync() throws {
        try self.connect(self.testDevices.streamDevice)
        let stream = try self.connection.createStream()
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
        try self.connect(self.testDevices.tunnelDevice)
        let tunnel = try self.connection.createTcpTunnel()
        XCTAssertThrowsError(try tunnel.getLocalPort()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.INVALID_STATE)
        }
    }

    func testTunnelOpenClose() throws {
        try self.connect(self.testDevices.tunnelDevice)
        let tunnel = try self.connection.createTcpTunnel()
        try tunnel.open(service: "http", localPort: 0)
        let port = try tunnel.getLocalPort()
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
        try self.connect(self.testDevices.tunnelDevice)
        let tunnel = try self.connection.createTcpTunnel()
        XCTAssertThrowsError(try tunnel.open(service: "httpblab", localPort: 0)) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.NOT_FOUND)
        }
    }

    func testTunnelOpenAfterClientStop() throws {
//        try self.connect(self.tunnelDevice)
//        let tunnel = try self.connection.createTcpTunnel()
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
//            try self.testTunnelOpenCloseAsync()
//            try self.tearDownWithError()
//        }
//    }

    func testTunnelOpenCloseAsync() throws {
        try self.connect(self.testDevices.tunnelDevice)

//        let connection = try client.createConnection()
//        let key = try client.createPrivateKey()
//        try connection.setPrivateKey(key: key)
//        try connection.updateOptions(json: self.tunnelDevice.asJson())
//        try connection.connect()

        let tunnel = try connection.createTcpTunnel()
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
        try self.connect(self.testDevices.tunnelDevice)
        let tunnel = try self.connection.createTcpTunnel()
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
        try self.connect(self.testDevices.tunnelDevice)
        let tunnel = try self.connection.createTcpTunnel()
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

    func testPasswordAuthAsyncFail() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        self.connection.passwordAuthenticateAsync(username: "", password: "wrong-password") { ec in
            XCTAssertEqual(ec, .UNAUTHORIZED)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func testPasswordAuthAsyncOk() throws {
        let key = try client.createPrivateKey()
        try self.connection.setPrivateKey(key: key)
        try self.connection.updateOptions(json: testDevices.passwordProtectedDevice.asJson())
        try self.connection.connect()
        let exp = XCTestExpectation(description: "expect connect callback")
        self.connection.passwordAuthenticateAsync(username: "", password: "open-password") { ec in
            XCTAssertEqual(ec, .OK)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30.0)
    }

    func testGracefullyHandleConnectionLivesLongerThanClient() throws {
        // clean up test objects created in setup to not confuse log output
        try self.tearDownWithError()

        var cli: Client! = Client()
        try self.enableLogging(cli)
        let conn: Connection! = try cli.createConnection()
        let key = try cli.createPrivateKey()
        try conn.setPrivateKey(key: key)
        try conn.updateOptions(json: self.testDevices.coapDevice.asJson())

        try conn.connect()
        cli.stop()
        cli = nil

        // with 5.8, it is ok to create (but not execute) coap request after stop
        let _ = try conn.createCoapRequest(method: "GET", path: "/foo")

        XCTAssertThrowsError(try conn.close()) { error in
            XCTAssertEqual(error as! NabtoEdgeClientError, NabtoEdgeClientError.STOPPED)
        }
    }

    func testAsyncConnectionCloseAfterClientStop() throws {
        // clean up test objects created in setup to not confuse log output
        try self.tearDownWithError()

        var conn: Connection!
        do {
            let cli = Client()
            try self.enableLogging(cli)
            conn = try cli.createConnection()
            let key = try cli.createPrivateKey()
            try conn.setPrivateKey(key: key)
            try conn.updateOptions(json: self.testDevices.coapDevice.asJson())
            try conn.connect()
        }

        let exp = XCTestExpectation()
        conn.closeAsync { ec in
            XCTAssertEqual(ec, NabtoEdgeClientError.STOPPED)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

//    // make sure nabto4 symbols are present in test executable: some nabto5 tests crashed prior to 5.7 if binary was
//    // linked with nabto4
//    func testNabto4() {
//        let nabto4 = NabtoClient.instance() as! NabtoClient
//        XCTAssertEqual("4.", nabto4.nabtoVersionString().prefix(2))
//    }

// reproduce leak caused by pre-sc764 stop behavior: it was possible to invoke free from a callback
// initiated after client stop - and this free was ignored (test requires instrumented
// api_context.hpp that e.g. aborts in ApiContext:free if invoked from the callback thread)
    func testStopLeak() throws {
        try self.tearDownWithError()

        var connection: Connection!
        let exp = XCTestExpectation(description: "callback waits until end of scope of this function")
        do {
            var client: Client!
            do {
                client = Client()
                connection = try client.createConnection()

                let key = try client.createPrivateKey()
                try connection.setPrivateKey(key: key)
                try connection.updateOptions(json: self.testDevices.coapDevice.asJson())
                try connection.connect()
                let coap = try connection.createCoapRequest(method: "GET", path: "/hello-world")

                client.stop()

                // with pre-sc764 implementation, below does not fail but triggers leak
                coap.executeAsync { error, response in
                    self.wait(for: [exp], timeout: 10.0)
                    XCTAssertEqual(error, .STOPPED)
                    XCTAssertNil(response)
                    connection = nil
                }
            }
            client = nil
        }
        // callback keeps connection alive which keeps ClientImpl alive - when finally deinitializing ClientImpl
        // from sdk callback thread, free is ignored in ApiContext::free()
        exp.fulfill()
    }
}
