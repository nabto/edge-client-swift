//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi
import os.log

public class Connection: NSObject {

    private let plaincNabtoConnection: OpaquePointer

    internal init(nabtoClient: OpaquePointer) throws {
        let p = nabto_client_connection_new(nabtoClient)
        if (p != nil) {
            self.plaincNabtoConnection = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
    }

    deinit {
        nabto_client_connection_free(self.plaincNabtoConnection)
    }

    public func updateOptions(json: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_options(self.plaincNabtoConnection, json)
        if (status != NABTO_CLIENT_EC_OK) {
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }

    public func getOptions() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_options(self.plaincNabtoConnection, &p)
        return try handleStringResult(status: status, cstring: p)
    }

    public func getDeviceFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_device_fingerprint_full_hex(self.plaincNabtoConnection, &p)
        return try handleStringResult(status: status, cstring: p)
    }

    public func getClientFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_device_fingerprint_full_hex(self.plaincNabtoConnection, &p)
        return try handleStringResult(status: status, cstring: p)
    }

    private func handleStringResult(status: NabtoClientError, cstring: UnsafeMutablePointer<Int8>?) throws -> String {
        if (status == NABTO_CLIENT_EC_INVALID_STATE) {
            throw NabtoEdgeClientError.INVALID_STATE
        } else if (status != NABTO_CLIENT_EC_OK || cstring == nil) {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        let result = String(cString: cstring!)
        nabto_client_string_free(cstring)
        return result
    }

}
