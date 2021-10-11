//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

// useful read: https://www.uraimo.com/2016/04/07/swift-and-c-everything-you-need-to-know

/**
 * This class allows inferior objects (e.g. connections, streams) to keep a client reference without
 * triggering nabto_client_stop from an SDK callback (forbidden and wreaks havoc) when the last such client
 * reference goes out of scope.
 *
 * When the swift Client instance goes out of scope, ClientImpl invokes nabto_client_stop which
 * blocks until all SDK callbacks are done (pending callbacks are triggered with abort status), ie
 * no nabto_client_stop or nabto_client_free is triggered from callbacks indirectly through deinit
 * invocations.
 */
internal class ClientImpl: NSObject, NativeClientWrapper {

    internal let nativeClient: OpaquePointer
    private var userLogCallBack: LogCallBackReceiver?
    private var apiLogCallBackRegistered: Bool = false

    /**
     * Create a new instance of the Nabto Edge client.
     */
    override public init() {
        self.nativeClient = nabto_client_new()
        print("*** Client.init done, client=\(self.nativeClient)")
        super.init()
    }

    deinit {
        self.stop()
        nabto_client_free(self.nativeClient)
        print("*** Client.deinit done, client=\(self.nativeClient)")
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
        return try Connection(client: self)
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
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_create_private_key(self.nativeClient, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
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
        return MdnsScanner(client: self, subType: subType)
    }


    /**
     * Enable logging messages from the underlying SDK using NSLog.
     */
    public func enableNsLogLogging() {
        self.setLogCallBack(cb: ClientImpl.nslogLogCallback)
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
     *
     * If SDK logging has been configured, this function MUST be called, otherwise Client instances are leaked.
     */
    public func stop() {
        if (self.apiLogCallBackRegistered) {
            nabto_client_set_log_callback(self.nativeClient, nil, nil)
        }
        nabto_client_stop(self.nativeClient)
    }

    private static func nslogLogCallback(msg: NabtoEdgeClientLogMessage) {
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
            let mySelf = Unmanaged<ClientImpl>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiLogCallback(msg: msg)
        }, rawSelf)
        if (res == NABTO_CLIENT_EC_OK) {
            self.apiLogCallBackRegistered = true
        }
    }

}
