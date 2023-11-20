//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

/**
 * Often used CoAP content formats, see https://www.iana.org/assignments/core-parameters/core-parameters.xhtml for
 * exhaustive list.
 */
public enum ContentFormat: UInt16 {
    /**
     * Plain text content
     */
    case TEXT_PLAIN = 0
    /**
     * XML content
     */
    case APPLICATION_XML = 41
    /**
     * Data stream content
     */
    case APPLICATION_OCTET_STREAM = 42
    /**
     * Json encoded content
     */
    case APPLICATION_JSON = 50
    /**
     * Cbor encoded content
     */
    case APPLICATION_CBOR = 60
}

/**
 * Callback invoked when a CoAP response is ready or a CoAP request has failed.
 *
 * @param NabtoEdgeClientError error code indicating if request succeeded
 * @param CoapResponse Resulting CoAP response if the error code was OK
 */
public typealias CoapResponseReceiver = (NabtoEdgeClientError, CoapResponse?) -> Void

/**
 * This class represents a CoAP request on an open connection, ready to be executed.
 *
 * Instances are created using createCoapRequest() function on the Connection class.
 * The CoapRequest object must be kept alive while in use.
 *
 * See https://docs.nabto.com/developer/guides/get-started/coap/intro.html for info about Nabto Edge
 * CoAP.
 */
public class CoapRequest {

    private let client: NativeClientWrapper
    private let connection: NativeConnectionWrapper
    private let coap: OpaquePointer
    private let helper: Helper

    internal init(client: NativeClientWrapper, connection: NativeConnectionWrapper, method: String, path: String) throws {
        let validMethods = ["GET", "POST", "PUT", "DELETE"]
        if (validMethods.firstIndex(of: method) == nil) {
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
        if let p = nabto_client_coap_new(connection.nativeConnection, method, path) {
            self.coap = p
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        // keep a swift level connection (ie to NativeConnectionWrapper instance vs
        // raw OpaquePointer) to prevent them from being freed by ARC if owning app only keeps reference to coap obj
        self.client = client
        self.connection = connection
        self.helper = Helper(client: client)
    }

    deinit {
        nabto_client_coap_free(self.coap)
    }

    /**
     * Set payload and content format for the payload.
     * @param contentFormat See https://www.iana.org/assignments/core-parameters/core-parameters.xhtml, some often used values are defined in ContentFormat.
     * @param data Data for the request encoded as specified in the `contentFormat` parameter.
     * @throws NabtoEdgeClientError.FAILED if payload could not be set
     */
    public func setRequestPayload(contentFormat: UInt16, data: Data) throws {
        var status: NabtoClientError?
        data.withUnsafeBytes { p in
            let rawPtr = p.baseAddress!
            status = nabto_client_coap_set_request_payload(self.coap, contentFormat, rawPtr, data.count)
        }
        try Helper.throwIfNotOk(status)
    }

    /**
     * Convenience function for setting string payloads.
     * @param contentFormat See https://www.iana.org/assignments/core-parameters/core-parameters.xhtml, some often used values are defined in ContentFormat.
     * @param string String to set as payload.
     * @throws NabtoEdgeClientError.FAILED if payload could not be set
     */
    public func setRequestPayloadString(contentFormat: UInt16, string: String) throws {
        let status = nabto_client_coap_set_request_payload(self.coap, contentFormat, string, string.count)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Execute a CoAP request synchronously.
     *
     * When the function returns, the CoapResponse object is populated with response data and ready
     * to use. The response can indicate a remote error. If an error occurs that prevents creating a
     * response with a status code, an exception is thrown.
     *
     * @throws NabtoEdgeClientError if a response could not be created
     */
    public func execute() throws -> CoapResponse {
        try self.helper.wait { future in
            nabto_client_coap_execute(self.coap, future)
        }
        return try CoapResponse(self.coap)
    }

    /**
     * Execute a CoAP request asynchronously.
     *
     * The specified closure is invoked when the response is ready or an early error occurs.
     *
     * If a response is available, the first parameter in the CoapResponseReceiver closure
     * invocation is OK and the second parameter is set to the created CoapResponse.
     *
     * If an early error occurs, the first parameter is set to an appropriate NabtoEdgeClientError
     * and the second parameter is nil.
     *
     * @param closure invoked when async operation completes
     */
    public func executeAsync(closure: @escaping CoapResponseReceiver) {
        let future: OpaquePointer = nabto_client_future_new(client.nativeClient)
        nabto_client_coap_execute(self.coap, future)
        let w = CallbackWrapper(debugDescription: "coap.executeAsync", future: future, owner: self, connectionForErrorMessage: self.connection)
        let status = w.registerCallback { ec in
            if (ec == .OK) {
                do {
                    let coapResponse = try CoapResponse(self.coap)
                    closure(.OK, coapResponse)
                } catch {
                    let coapEc = error as? NabtoEdgeClientError
                    closure(coapEc ?? NabtoEdgeClientError.UNEXPECTED_API_STATUS, nil)
                }
            } else {
                closure(ec, nil)
            }
        }
        if (status != NABTO_CLIENT_EC_OK) {
            self.helper.invokeUserClosureAsyncFail(status, { asyncInvokeEc in
                closure(asyncInvokeEc, nil)
            })
        }
    }
    
    /**
     * Execute a CoAP request asynchronously..
     *
     * When the function returns, the CoapResponse object is populated with response data and ready
     * to use. The response can indicate a remote error. If an error occurs that prevents creating a
     * response with a status code, an exception is thrown.
     *
     * @throws NabtoEdgeClientError if a response could not be created
     */
    @available(iOS 13.0, *)
    public func executeAsync2() async throws -> CoapResponse {
        let future: OpaquePointer = nabto_client_future_new(client.nativeClient)
        nabto_client_coap_execute(self.coap, future)
        let w = CallbackWrapper(debugDescription: "coap.executeAsync2", future: future, owner: self, connectionForErrorMessage: self.connection)
        let res = try await withCheckedThrowingContinuation { continuation in
            let status = w.registerCallback { ec in
                if ec == .OK {
                    do {
                        let coapResponse = try CoapResponse(self.coap)
                        continuation.resume(returning: coapResponse)
                    } catch {
                        let coapEc = error as? NabtoEdgeClientError
                        continuation.resume(throwing: coapEc ?? NabtoEdgeClientError.UNEXPECTED_API_STATUS)
                    }
                } else {
                    continuation.resume(throwing: ec)
                }
            }
            if status != NABTO_CLIENT_EC_OK {
                self.helper.invokeUserClosureAsyncFail(status, { asyncInvokeEc in continuation.resume(throwing: asyncInvokeEc) })
            }
        }
        return res
    }

    /**
     * Stop any pending async request executions.
     *
     * The request should not be used after it has been stopped.
     */
    public func stop() {
        nabto_client_coap_stop(self.coap)
    }
}
