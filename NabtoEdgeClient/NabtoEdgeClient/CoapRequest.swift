//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public enum ContentFormat: UInt16 {
    case TEXT_PLAIN = 0
    case APPLICATION_XML = 41
    case APPLICATION_OCTET_STREAM = 42
    case APPLICATION_CBOR = 60
}

public class CoapRequest {

    private let client: NativeClientWrapper
    private let connection: NativeConnectionWrapper
    private let coap: OpaquePointer
    private let helper: Helper

    internal init(nabtoClient: NativeClientWrapper, nabtoConnection: NativeConnectionWrapper, method: String, path: String) throws {
        let p = nabto_client_coap_new(nabtoConnection.nativeConnection, method, path)
        if (p != nil) {
            self.coap = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        // keep a swift level reference to client and connection (ie to Native{Client|Connecton}Wrapper instance vs
        // raw OpaquePointer) to prevent them from being freed by ARC if owning app only keeps reference to coap obj
        self.client = nabtoClient
        self.connection = nabtoConnection
        self.helper = Helper(nabtoClient: self.client)
    }

    deinit {
        nabto_client_coap_free(self.coap)
    }

    public func setRequestPayload(contentFormat: UInt16, data: Data) throws {
        var status: NabtoClientError?
        data.withUnsafeBytes { p in
            let rawPtr = p.baseAddress!
            status = nabto_client_coap_set_request_payload(self.coap, contentFormat, rawPtr, data.count)
        }
        try Helper.throwIfNotOk(status)
    }

    public func setRequestPayload(contentFormat: UInt16, string: String) throws {
        let status = nabto_client_coap_set_request_payload(self.coap, contentFormat, string, string.count)
        try Helper.throwIfNotOk(status)
    }

    public func execute() throws {
        try self.helper.wait() { future in
            nabto_client_coap_execute(self.coap, future)
        }
    }

    public func getResponseStatusCode() throws -> UInt16 {
        var statusCode: UInt16 = 0
        let status = nabto_client_coap_get_response_status_code(self.coap, &statusCode)
        try Helper.throwIfNotOk(status)
        return statusCode
    }

    public func getResponseContentFormat() throws-> UInt16 {
        var contentType: UInt16 = 0
        let status = nabto_client_coap_get_response_content_format(self.coap, &contentType)
        try Helper.throwIfNotOk(status)
        return contentType
    }

    public func getResponsePayload() throws -> Data {
        var payload: UnsafeMutableRawPointer?
        var length: Int = 0
        let status = nabto_client_coap_get_response_payload(self.coap, &payload, &length)
        try Helper.throwIfNotOk(status)
        return Data(bytes: payload!, count: length)
    }
}