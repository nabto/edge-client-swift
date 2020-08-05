//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public class CoapRequest {

    private let plaincNabtoClient: OpaquePointer
    private let plaincCoapRequest: OpaquePointer

    internal init(nabtoClient: OpaquePointer, nabtoConnection: OpaquePointer, method: String, path: String) throws {
        let p = nabto_client_coap_new(nabtoConnection, method, path)
        if (p != nil) {
            self.plaincCoapRequest = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        self.plaincNabtoClient = nabtoClient
    }

    deinit {
        nabto_client_coap_free(self.plaincCoapRequest)
    }

    public func setRequestPayload(contentFormat: UInt16, data: Data) throws {
        var status: NabtoClientError?
        data.withUnsafeBytes { p in
            let rawPtr = p.baseAddress!
            status = nabto_client_coap_set_request_payload(self.plaincCoapRequest, contentFormat, rawPtr, data.count)
        }
        try Helper.throwIfNotOk(status)
    }

    public func setRequestPayload(contentFormat: UInt16, string: String) throws {
        let status = nabto_client_coap_set_request_payload(self.plaincCoapRequest, contentFormat, string, string.count)
        try Helper.throwIfNotOk(status)
    }

    public func execute() throws {
        let future = nabto_client_future_new(self.plaincNabtoClient)
        nabto_client_coap_execute(self.plaincCoapRequest, future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        try Helper.throwIfNotOk(status)
    }

    public func getResponseStatusCode() throws -> UInt16 {
        var statusCode: UInt16 = 0
        let status = nabto_client_coap_get_response_status_code(self.plaincCoapRequest, &statusCode)
        try Helper.throwIfNotOk(status)
        return statusCode
    }

    public func getResponseContentFormat() throws-> UInt16 {
        var contentType: UInt16 = 0
        let status = nabto_client_coap_get_response_content_format(self.plaincCoapRequest, &contentType)
        try Helper.throwIfNotOk(status)
        return contentType
    }

    public func getResponsePayload() throws -> Data {
        var payload: UnsafeMutableRawPointer?
        var length: Int = 0
        let status = nabto_client_coap_get_response_payload(self.plaincCoapRequest, &payload, &length)
        try Helper.throwIfNotOk(status)
        return Data(bytes: payload!, count: length)
    }
}