//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

// ensures client is kept alive until future is resolved
internal class CallbackWrapper : NSObject {
    let client: NativeClientWrapper
    let connection: NativeConnectionWrapper?
    let future: OpaquePointer
    let cb: AsyncStatusReceiver
    var cleanupClosure: (() -> Void)?

    init(client: NativeClientWrapper,
         connection: NativeConnectionWrapper?,
         future: OpaquePointer,
         cb: @escaping AsyncStatusReceiver) {
        self.client = client
        self.connection = connection
        self.future = future
        self.cb = cb
        super.init()
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
        self.cb(wrapperError)
        nabto_client_future_free(self.future)
        self.cleanupClosure?()
    }
}

internal class Helper {

    private let client: NativeClientWrapper
    private var activeCallbacks: Set<CallbackWrapper> = Set<CallbackWrapper>()

    init(nabtoClient: NativeClientWrapper) {
        self.client = nabtoClient
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
        case NABTO_CLIENT_EC_NO_DATA: return NabtoEdgeClientError.NO_DATA
        case NABTO_CLIENT_EC_OPERATION_IN_PROGRESS: return NabtoEdgeClientError.OPERATION_IN_PROGRESS
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
        let future = nabto_client_future_new(self.client.nativeClient)
        closure(future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        return status
    }

    internal func wait(closure: (OpaquePointer?) -> Void) throws {
        try Helper.throwIfNotOk(self.waitNoThrow(closure: closure))
    }

    internal func futureCallback(closure: (OpaquePointer?) -> Void) throws {
        let future = nabto_client_future_new(self.client.nativeClient)
        closure(future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        try Helper.throwIfNotOk(status)
    }

    internal func invokeAsync(userClosure: @escaping AsyncStatusReceiver,
                              connection: NativeConnectionWrapper?,
                              implClosure: (OpaquePointer) -> Void) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        implClosure(future)
        let w = CallbackWrapper(client: self.client, connection: connection, future: future, cb: userClosure)
        w.setCleanupClosure(cleanupClosure: {
            self.activeCallbacks.remove(w)}
        )
        self.activeCallbacks.insert(w)
    }




}
