//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

/* TODO nabtodoc
 * Connection events.
 *
 * Listen for these using `addConnectionEventsListener()` on a Connection object.
 */
@objc public enum NabtoEdgeClientConnectionEvent: Int {
    case CONNECTED
    case CLOSED
    case CHANNEL_CHANGED
    case UNEXPECTED_EVENT
}

/* TODO nabtodoc
 * Callback function to receive Connection events.
 */
@objc public protocol ConnectionEventsCallbackReceiver {
    func onEvent(event: NabtoEdgeClientConnectionEvent)
}

internal protocol NativeConnectionWrapper {
    var nativeConnection: OpaquePointer { get }
}

/**
 * This class represents a connection to a specific Nabto Edge device.
 *
 * Instances are created using `NabtoEdgeClient.createConnection()`.
 */
public class Connection: NSObject, NativeConnectionWrapper {
    internal let nativeConnection: OpaquePointer
    private let client: NativeClientWrapper
    private let helper: Helper
    private var apiEventCallBackRegistered: Bool = false
    private var connectionEventListener: ConnectionEventListener? = nil

    internal init(client: NativeClientWrapper) throws {
        let p = nabto_client_connection_new(client.nativeClient)
        if (p != nil) {
            self.nativeConnection = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        // keep a swift level reference to client (ie to NativeClientWrapper instance vs raw OpaquePointer) to prevent client
        // from being freed by ARC if owning app only keeps reference to connection
        self.client = client
        self.helper = Helper(nabtoClient: self.client)
    }

    deinit {
        nabto_client_connection_free(self.nativeConnection)
    }

    public func connect() throws {
        let status = self.helper.waitNoThrow { future in
            nabto_client_connection_connect(self.nativeConnection, future)
        }
        if (status == NABTO_CLIENT_EC_NO_CHANNELS) {
            throw Helper.createConnectionError(connection: self)
        } else {
            try Helper.throwIfNotOk(status)
        }
    }

    public func connectAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: self) { future in
            nabto_client_connection_connect(self.nativeConnection, future)
        }
    }

    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }

    public func close() throws {
        try helper.wait() { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }

    /**
     * Set connection options. Options must be set prior to invoking `connect()`.
     */
    public func updateOptions(json: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_options(self.nativeConnection, json)
        try Helper.throwIfNotOk(status)
    }

    public func getOptions() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_options(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func setPrivateKey(key: String) throws {
        let status = nabto_client_connection_set_private_key(self.nativeConnection, key)
        return try Helper.throwIfNotOk(status)
    }

    public func getDeviceFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_device_fingerprint_full_hex(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func getClientFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_client_fingerprint_full_hex(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func createStream() throws -> Stream {
        return try Stream(nabtoClient: self.client, nabtoConnection: self)
    }

    public func createCoapRequest(method: String, path: String) throws -> CoapRequest {
        return try CoapRequest(nabtoClient: self.client, nabtoConnection: self, method: method, path: path)
    }

    public func createTcpTunnel() throws -> Tunnel {
        return try Tunnel(nabtoClient: self.client, nabtoConnection: self)
    }

    // may throw NabtoEdgeClientError.INVALID_STATE
    public func addConnectionEventsListener(cb: ConnectionEventsCallbackReceiver) throws {
        if (self.connectionEventListener == nil) {
            self.connectionEventListener = try ConnectionEventListener(nabtoConnection: self, nabtoClient: self.client)
        }
        self.connectionEventListener!.addUserCb(cb)
    }

    public func removeConnectionEventsListener(cb: ConnectionEventsCallbackReceiver) throws {
        guard let listener = self.connectionEventListener else {
            return
        }
        listener.removeUserCb(cb)
    }

}
