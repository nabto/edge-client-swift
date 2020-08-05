//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public class Connection: NSObject {

    private let plaincNabtoConnection: OpaquePointer
    private let plaincNabtoClient: OpaquePointer

    internal init(nabtoClient: OpaquePointer) throws {
        let p = nabto_client_connection_new(nabtoClient)
        if (p != nil) {
            self.plaincNabtoConnection = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        self.plaincNabtoClient = nabtoClient
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

    public func close() {
        // TODO
    }

    public func addConnectionEventsListener() {
        // TODO
    }

    public func removeConnectionEventsListener() {
        // TODO
    }



}
