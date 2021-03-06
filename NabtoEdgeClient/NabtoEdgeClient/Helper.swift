//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

// ensures client is kept alive until future is resolved
internal class CallbackWrapper : NSObject {
    var client: Client
    var connection: Connection?
    let future: OpaquePointer
    var cb: AsyncStatusReceiver?
    var cleanupClosure: (() -> Void)?

    init(client: Client,
         connection: Connection?,
         future: OpaquePointer) {
        self.client = client
        self.connection = connection
        self.future = future
    }

    public func registerCallback(_ cb: @escaping AsyncStatusReceiver) {
        self.cb = cb
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<CallbackWrapper>.fromOpaque(data!).takeUnretainedValue()
            let wrapperError = mySelf.mapToWrapperError(ec: ec)
            mySelf.invokeUserCallback(wrapperError)

        }, rawSelf)
    }

    private func mapToWrapperError(ec: NabtoClientError) -> NabtoEdgeClientError {
        let wrapperError: NabtoEdgeClientError
        if (ec == NABTO_CLIENT_EC_NO_CHANNELS) {
            if (connection != nil) {
                wrapperError = Helper.createConnectionError(connection: connection!)
            } else {
                wrapperError = NabtoEdgeClientError.UNEXPECTED_API_STATUS
            }
        } else {
            wrapperError = Helper.mapSimpleApiStatusToErrorCode(ec)
        }
        return wrapperError
    }

    func setCleanupClosure(cleanupClosure: @escaping () -> Void) {
        self.cleanupClosure = cleanupClosure
    }

    func invokeUserCallback(_ wrapperError: NabtoEdgeClientError) {
        self.cb?(wrapperError)
        nabto_client_future_free(self.future)
        self.cleanupClosure?()
    }
}

internal class Helper {

    private weak var client: Client?
    private var activeCallbacks: Set<CallbackWrapper> = Set<CallbackWrapper>()

    init(nabtoClient: Client) {
        self.client = nabtoClient
    }

    deinit {
    }

    internal static func mapSimpleApiStatusToErrorCode(_ status: NabtoClientError) -> NabtoEdgeClientError {
        switch (status) {
        case NABTO_CLIENT_EC_OK: return NabtoEdgeClientError.OK

        case NABTO_CLIENT_EC_ABORTED: return NabtoEdgeClientError.ABORTED
        case NABTO_CLIENT_EC_CONNECTION_REFUSED: return NabtoEdgeClientError.CONNECTION_REFUSED
        case NABTO_CLIENT_EC_DNS: return NabtoEdgeClientError.DNS
        case NABTO_CLIENT_EC_EOF: return NabtoEdgeClientError.EOF
        case NABTO_CLIENT_EC_FORBIDDEN: return NabtoEdgeClientError.FORBIDDEN
        case NABTO_CLIENT_EC_INVALID_ARGUMENT: return NabtoEdgeClientError.INVALID_ARGUMENT
        case NABTO_CLIENT_EC_INVALID_STATE: return NabtoEdgeClientError.INVALID_STATE
        case NABTO_CLIENT_EC_NONE: return NabtoEdgeClientError.NONE
        case NABTO_CLIENT_EC_NOT_ATTACHED: return NabtoEdgeClientError.NOT_ATTACHED
        case NABTO_CLIENT_EC_NOT_CONNECTED: return NabtoEdgeClientError.NOT_CONNECTED
        case NABTO_CLIENT_EC_NOT_FOUND: return NabtoEdgeClientError.NOT_FOUND
        case NABTO_CLIENT_EC_NO_DATA: return NabtoEdgeClientError.OK
        case NABTO_CLIENT_EC_OPERATION_IN_PROGRESS: return NabtoEdgeClientError.OPERATION_IN_PROGRESS
        case NABTO_CLIENT_EC_STOPPED: return NabtoEdgeClientError.STOPPED
        case NABTO_CLIENT_EC_TIMEOUT: return NabtoEdgeClientError.TIMEOUT
        case NABTO_CLIENT_EC_TOKEN_REJECTED: return NabtoEdgeClientError.TOKEN_REJECTED
        case NABTO_CLIENT_EC_UNAUTHORIZED: return NabtoEdgeClientError.UNAUTHORIZED
        case NABTO_CLIENT_EC_UNKNOWN_DEVICE_ID: return NabtoEdgeClientError.UNKNOWN_DEVICE_ID
        case NABTO_CLIENT_EC_UNKNOWN_PRODUCT_ID: return NabtoEdgeClientError.UNKNOWN_PRODUCT_ID
        case NABTO_CLIENT_EC_UNKNOWN_SERVER_KEY: return NabtoEdgeClientError.UNKNOWN_SERVER_KEY
        case NABTO_CLIENT_EC_UNKNOWN: return NabtoEdgeClientError.FAILED

        default:
            let str = String(cString: nabto_client_error_get_string(status))
            NSLog("Unexpected API status \(status): \(str)")
            return .UNEXPECTED_API_STATUS
        }
    }

    internal static func createConnectionError(connection: NativeConnectionWrapper) -> NabtoEdgeClientError {
        let localError = Helper.mapSimpleApiStatusToErrorCode(nabto_client_connection_get_local_channel_error_code(connection.nativeConnection))
        let remoteError = Helper.mapSimpleApiStatusToErrorCode(nabto_client_connection_get_remote_channel_error_code(connection.nativeConnection))
        return NabtoEdgeClientError.NO_CHANNELS(localError: localError, remoteError: remoteError)
    }

    internal static func throwIfNotOk(_ status: NabtoClientError?) throws {
        if (status == nil) {
            throw NabtoEdgeClientError.UNEXPECTED_API_STATUS
        }
        let error: NabtoEdgeClientError = mapSimpleApiStatusToErrorCode(status!)
        if (error != .OK) {
            throw error
        }
    }

    internal static func handleStringResult(status: NabtoClientError, cstring: UnsafeMutablePointer<Int8>?) throws -> String {
        try throwIfNotOk(status)
        if (cstring == nil) {
            throw NabtoEdgeClientError.FAILED
        }
        let result = String(cString: cstring!)
        nabto_client_string_free(cstring)
        return result
    }

    internal func waitNoThrow(closure: (OpaquePointer?) -> Void) -> NabtoClientError {
        if let client = self.client {
            let future = nabto_client_future_new(client.nativeClient)
            closure(future)
            nabto_client_future_wait(future)
            let status = nabto_client_future_error_code(future)
            nabto_client_future_free(future)
            return status
        } else {
            return NABTO_CLIENT_EC_ABORTED
        }
    }

    internal func wait(closure: (OpaquePointer?) -> Void) throws {
        try Helper.throwIfNotOk(self.waitNoThrow(closure: closure))
    }


    func invokeAsync(userClosure: @escaping AsyncStatusReceiver, connection: Connection?, implClosure: (OpaquePointer) -> ()) {
        if let client = self.client {
            let future: OpaquePointer = nabto_client_future_new(client.nativeClient)

            // invoke actual api function specified by caller (e.g. nabto_client_connection_connect)
            implClosure(future)

            // keep client and connection swift objects alive until future resolves
            let w = CallbackWrapper(client: client, connection: connection, future: future)
            self.activeCallbacks.insert(w)

            // when future resolves, remove reference to client and connection and allow them to be reclaimed
            w.setCleanupClosure(cleanupClosure: {  [weak w] in
                if let w = w {
                    self.activeCallbacks.remove(w)
                }
            })

            // set callback on future (nabto_client_future_set_callback)
            w.registerCallback(userClosure)
        } else {
            abort(userClosure)
        }
    }

    private func abort(_ closure: @escaping (NabtoEdgeClientError) -> ()) {
        // Do not invoke user callback in same callstack. Use a background queue (vs main) as caller can have no
        // expectations about callback should happen on main thread; under normal circumstances, callback would happen
        // in a thread started by the native client SDK.
        DispatchQueue.global().async {
            closure(.ABORTED)
        }
    }
}
