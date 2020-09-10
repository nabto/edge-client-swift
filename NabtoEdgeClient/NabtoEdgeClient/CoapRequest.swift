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

public typealias CoapResponseReceiver = (NabtoEdgeClientError, CoapResponse?) -> Void

public class CoapRequest {

    private let client: NativeClientWrapper
    private let connection: NativeConnectionWrapper
    private let coap: OpaquePointer
    private let helper: Helper
    private var activeCallbacks: Set<CallbackWrapper> = Set<CallbackWrapper>()

    internal init(nabtoClient: NativeClientWrapper, nabtoConnection: NativeConnectionWrapper, method: String, path: String) throws {
        let validMethods = ["GET", "POST", "PUT", "DELETE"]
        if (validMethods.firstIndex(of: method) == nil) {
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
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

    public func execute() throws -> CoapResponse {
        try self.helper.wait() { future in
            nabto_client_coap_execute(self.coap, future)
        }
        return try CoapResponse(self.coap)
    }

    public func executeAsync(closure: @escaping CoapResponseReceiver) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        nabto_client_coap_execute(self.coap, future)
        let w = CallbackWrapper(client: self.client, future: future, cb: { ec in
            if (ec == .OK) {
                do {
                    let coapResponse = try CoapResponse(self.coap)
                    closure(.OK, coapResponse)
                } catch (let error) {
                    let coapEc = error as? NabtoEdgeClientError
                    closure(coapEc ?? NabtoEdgeClientError.UNEXPECTED_API_STATUS, nil)
                }
            } else {
                closure(ec, nil)
            }
        })
        w.setCleanupClosure(cleanupClosure: {
            self.activeCallbacks.remove(w)
        })
        self.activeCallbacks.insert(w)
    }

}