//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

// useful read: https://www.uraimo.com/2016/04/07/swift-and-c-everything-you-need-to-know

/* TODO nabtodoc
 * Error codes directly mapped from the underlying core SDK.
```
    OK
    ABORTED
    ALLOCATION_ERROR
    EOF
    FORBIDDEN
    NOT_FOUND
    INVALID_ARGUMENT
    INVALID_STATE
    NO_CHANNELS
    NO_DATA
    NOT_CONNECTED
    OPERATION_IN_PROGRESS
    TIMEOUT
    UNEXPECTED_API_STATUS
```
 */
public indirect enum NabtoEdgeClientError: Error, Equatable {
    case OK

    case ABORTED
    case ALLOCATION_ERROR
    case CONNECTION_REFUSED
    case DNS
    case EOF
    case FORBIDDEN
    case INVALID_ARGUMENT
    case INVALID_STATE
    case NONE
    case NOT_ATTACHED
    case NOT_CONNECTED
    case NOT_FOUND
    case NO_CHANNELS(localError: NabtoEdgeClientError, remoteError: NabtoEdgeClientError)
    case NO_DATA
    case OPERATION_IN_PROGRESS
    case TIMEOUT
    case TOKEN_REJECTED
    case UNAUTHORIZED
    case UNKNOWN_DEVICE_ID
    case UNKNOWN_PRODUCT_ID
    case UNKNOWN_SERVER_KEY

    case UNEXPECTED_API_STATUS
}

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
public class NabtoEdgeClient: NSObject, NativeClientWrapper {

    internal let nativeClient: OpaquePointer
    private var userLogCallBack: LogCallBackReceiver?
    private var apiLogCallBackRegistered: Bool = false

    /**
     * Create a new instance of the Nabto Edge client.
     */
    override public init() {
        self.nativeClient = nabto_client_new()
    }

    deinit {
        nabto_client_free(self.nativeClient)
    }

    /**
     * Get the underlying SDK version.
     */
    static public func versionString() -> String {
        return String(cString: nabto_client_version())
    }

    /**
     * Create a connection object.
     */
    public func createConnection() throws -> Connection {
        return try Connection(client: self)
    }

    /**
     * Create a private key and return the private key as a pem encoded string.
     *
     * The result is normally stored in a device specific secure location and retrieved whenever a new connection
     * is established, passed on to a Connection object using `setPrivateKey()`.
     * @throws NabtoEdgeClientError.ALLOCATION_ERROR if key could not be created
     */
    public func createPrivateKey() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_create_private_key(self.nativeClient, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    /**
     * Log messages from the underlying SDK using NSLog.
     */
    public func enableNsLogLogging() {
        self.setLogCallBack(cb: nslogLogCallback)
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
        let status: NabtoClientError = nabto_client_set_log_level(self.nativeClient, level)
        if (status != NABTO_CLIENT_EC_OK) {
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }

    /**
     * Set a callback function for custom logging.
     *
     * @param cb: The LogCallBackReceiver invoked by the wrapper with SDK log lines.
     */
    public func setLogCallBack(cb: @escaping LogCallBackReceiver) {
        self.userLogCallBack = cb
        if (!self.apiLogCallBackRegistered) {
            self.registerApiLogCallback()
        } else {
            // nabto_client_set_log_callback seems to always succeed
        }
    }

    /**
     * Stop a client for final cleanup, this function is blocking until no more callbacks
     * are in progress or on the event or callback queues.
     */
    public func stop() {
        nabto_client_stop(self.nativeClient)
    }

    private func nslogLogCallback(msg: NabtoEdgeClientLogMessage) {
        NSLog("Nabto log: \(msg.file):\(msg.line) [\(msg.severity)/\(msg.severityString)]: \(msg.message)")
    }

    private func apiLogCallback(msg: NabtoClientLogMessage) {
        guard let cb = self.userLogCallBack else {
            return
        }
        let userMsg = NabtoEdgeClientLogMessage(
                severity: Int(msg.severity.rawValue),
                severityString: String(cString: msg.severityString),
                file: (String(cString: msg.file) as NSString).lastPathComponent,
                line: Int(msg.line),
                message: String(cString: msg.message))
        cb(userMsg)
    }

    private func registerApiLogCallback() {
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        let res = nabto_client_set_log_callback(self.nativeClient, { (pmsg: Optional<UnsafePointer<NabtoClientLogMessage>>, data: Optional<UnsafeMutableRawPointer>) -> Void in
            if (pmsg == nil || data == nil) {
                return
            }
            let msg: NabtoClientLogMessage = pmsg!.pointee
            let mySelf = Unmanaged<NabtoEdgeClient>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiLogCallback(msg: msg)
        }, rawSelf)
        if (res == NABTO_CLIENT_EC_OK) {
            self.apiLogCallBackRegistered = true
        }
    }

}
