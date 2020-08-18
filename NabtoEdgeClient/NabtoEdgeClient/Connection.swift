//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

@objc public enum NabtoEdgeClientConnectionEvent: Int {
    case CONNECTED
    case CLOSED
    case CHANNEL_CHANGED
    case UNEXPECTED_EVENT
}

@objc public protocol ConnectionEventsCallbackReceiver {
    func onEvent(event: NabtoEdgeClientConnectionEvent)
}

public class Connection: NSObject {

    private let plaincNabtoConnection: OpaquePointer
    private let plaincNabtoClient: OpaquePointer
    private let helper: Helper
    private var apiEventCallBackRegistered: Bool = false
    private var connectionEventListener: ConnectionEventListener? = nil

    internal init(nabtoClient: OpaquePointer) throws {
        let p = nabto_client_connection_new(nabtoClient)
        if (p != nil) {
            self.plaincNabtoConnection = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        self.plaincNabtoClient = nabtoClient
        self.helper = Helper(nabtoClient: self.plaincNabtoClient)
    }

    deinit {
        nabto_client_connection_free(self.plaincNabtoConnection)
    }

    public func updateOptions(json: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_options(self.plaincNabtoConnection, json)
        try Helper.throwIfNotOk(status)
    }

    public func getOptions() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_options(self.plaincNabtoConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func setPrivateKey(key: String) throws {
        let status = nabto_client_connection_set_private_key(self.plaincNabtoConnection, key)
        return try Helper.throwIfNotOk(status)
    }

    public func getDeviceFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_device_fingerprint_full_hex(self.plaincNabtoConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func getClientFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_client_fingerprint_full_hex(self.plaincNabtoConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    public func createStream() {
        // TODO
    }

    public func createCoapRequest(method: String, path: String) throws -> CoapRequest {
        return try CoapRequest(nabtoClient: self.plaincNabtoClient, nabtoConnection: self.plaincNabtoConnection, method: method, path: path)
    }

    public func createTcpTunnel() {
        // TODO
    }

    public func close() throws {
        try helper.wait() { future in
            nabto_client_connection_close(self.plaincNabtoConnection, future)
        }
    }

    public func connect() throws {
        try helper.wait() { future in
            nabto_client_connection_connect(self.plaincNabtoConnection, future)
        }
    }

    // may throw NabtoEdgeClientError.INVALID_STATE
    public func addConnectionEventsListener(cb: ConnectionEventsCallbackReceiver) throws {
        if (self.connectionEventListener == nil) {
            self.connectionEventListener = try ConnectionEventListener(plaincNabtoConnection: self.plaincNabtoConnection, plaincNabtoClient: self.plaincNabtoClient)
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
