//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

/* TODO nabtodoc
 * Callback function for receiving log messages from the core SDK.
 */
public typealias LogCallBackReceiver = (NabtoEdgeClientLogMessage) -> Void

/* TODO nabtodoc
 * Callback function for receiving API status codes asynchronously.
 */
public typealias AsyncStatusReceiver = (NabtoEdgeClientError) -> Void

/**
 * The log messages passed to registered `LogCallBackReceiver` callback functions.
 */
public struct NabtoEdgeClientLogMessage {
    var severity: Int
    var severityString: String
    var file: String
    var line: Int
    var message: String
}

internal protocol NativeClientWrapper {
    var nativeClient: OpaquePointer { get }
}

/**
 * This class is the main entry point for the Nabto Edge Client SDK Swift wrapper.
 *
 * It enables you to create a connection object, used to connect to a Nabto Edge Embedded device. And it provides misc
 * support functions: Create a private key (mandatory to later connect to a device), control logging, get SDK version.
 */
public class Client: NSObject {

    private let impl: ClientImpl

    /**
     * Create a new instance of the Nabto Edge client.
     */
    override public init() {
        self.impl = ClientImpl()
        super.init()
    }

    deinit {
        print("*** client deinit begin")
        self.impl.stop()
        print("*** client deinit end, thread: \(Thread.current)")
    }

    /**
     * Get the underlying SDK version.
     * @return the SDK version, e.g. 5.2.0-rc.1024+290f2fa
     */
    static public func versionString() -> String {
        return String(cString: nabto_client_version())
    }

    /**
     * Create a connection object.
     *
     * The created connection can then be configured and opened.
     *
     * @throws NabtoEdgeClientError.ALLOCATION_ERROR if the underlying SDK fails creating a connection object
     */
    public func createConnection() throws -> Connection {
        return try self.impl.createConnection()
    }

    /**
     * Create a private key and return the private key as a pem encoded string.
     *
     * The result is normally stored in a device specific secure location and retrieved whenever a new connection
     * is established, passed on to a Connection object using `setPrivateKey()`.
     * @throws NabtoEdgeClientError.FAILED if key could not be created
     * @return the private key as a pem encoded string.
     */
    public func createPrivateKey() throws -> String {
        return try self.impl.createPrivateKey()
    }

    /**
     * Create an mDNS scanner to discover local devices.
     *
     * @param subType the mDNS subtype to scan for: If nil or the empty string, the mDNS subtype
     * `_nabto._udp.local` is located; if subtype is specified, `[subtype]._sub._nabto._udp.local` is located.
     * @throws NabtoEdgeClientError
     * @return the MdnsScanner
     */
    public func createMdnsScanner(subType: String?=nil) -> MdnsScanner {
        return self.impl.createMdnsScanner(subType: subType)
    }

    /**
     * Enable logging messages from the underlying SDK using NSLog.
     */
    public func enableNsLogLogging() {
        return self.impl.enableNsLogLogging()
    }

    /**
     * Set the SDK log level.
     *
     * This needs to be set as early as possible to ensure modules are
     * initialised with the correct log settings.
     *
     * The default level is info.
     *
     * Lower case string for the desired log level.
     *
     * Allowed strings:
     *
     * Each severity level includes all the less severe levels.
     *
     * @param level: The log level: error, warn, info, debug or trace
     * @throws NabtoEdgeClientError.INVALID_ARGUMENT if invalid level
     */
    public func setLogLevel(level: String) throws {
        try self.impl.setLogLevel(level: level)
    }

    /**
     * Set a callback function for custom logging.
     *
     * @param cb: The LogCallBackReceiver invoked by the wrapper with SDK log lines.
     */
    public func setLogCallBack(cb: @escaping LogCallBackReceiver) {
        self.impl.setLogCallBack(cb: cb)
    }

    /**
     * Stop a client for final cleanup, this function is blocking until no more callbacks
     * are in progress or on the event or callback queues.
     *
     * If SDK logging has been configured, this function MUST be called, otherwise Client instances are leaked.
     */
    public func stop() {
        self.impl.stop()
    }
}
