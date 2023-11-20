//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

internal class Helper {

    private let client: NativeClientWrapper

    init(client: NativeClientWrapper) {
        self.client = client
    }

    deinit {
    }

    internal static func apiStatusToString(_ status: NabtoClientError) -> String {
        return String(cString: nabto_client_error_get_string(status))
    }

    static func mapSimpleApiStatusToErrorCode(_ status: NabtoClientError) -> NabtoEdgeClientError {
        switch (status) {
        case NABTO_CLIENT_EC_OK: return NabtoEdgeClientError.OK

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
        case NABTO_CLIENT_EC_UNKNOWN: return NabtoEdgeClientError.API_UNKNOWN_ERROR
        case NABTO_CLIENT_EC_TOO_MANY_REQUESTS: return NabtoEdgeClientError.TOO_MANY_WRONG_PASSWORD_ATTEMPTS
        case NABTO_CLIENT_EC_PORT_IN_USE: return NabtoEdgeClientError.PORT_IN_USE

        default:
            NSLog("Error: UNEXPECTED_API_STATUS \(status): \(apiStatusToString(status))")
            return .UNEXPECTED_API_STATUS
        }
    }

    internal static func mapToSwiftError(ec: NabtoClientError, connection: NativeConnectionWrapper? = nil) -> NabtoEdgeClientError {
        let swiftError: NabtoEdgeClientError
        if (ec == NABTO_CLIENT_EC_NO_CHANNELS) {
            if let connection = connection {
                swiftError = Helper.createConnectionError(connection: connection)
            } else {
                swiftError = NabtoEdgeClientError.UNEXPECTED_API_STATUS
            }
        } else {
            swiftError = Helper.mapSimpleApiStatusToErrorCode(ec)
        }
        return swiftError
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
        let future = nabto_client_future_new(client.nativeClient)
        closure(future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        return status
    }

    internal func wait(closure: (OpaquePointer?) -> Void) throws {
        try Helper.throwIfNotOk(self.waitNoThrow(closure: closure))
    }


    func invokeAsync(userClosure: @escaping AsyncStatusReceiver,
                     owner: Any,
                     connectionForErrorMessage: Connection?,
                     implClosure: (OpaquePointer) -> ()) {
        let future: OpaquePointer = nabto_client_future_new(client.nativeClient)

        // invoke actual api function specified by caller (e.g. nabto_client_connection_connect)
        implClosure(future)

        let w = CallbackWrapper(debugDescription: "Helper.invokeAsync", future: future, owner: owner, connectionForErrorMessage: connectionForErrorMessage)

        let status: NabtoClientError = w.registerCallback(userClosure)
        if (status != NABTO_CLIENT_EC_OK) {
            self.invokeUserClosureAsyncFail(status, userClosure)
        }
    }

    internal func invokeUserClosureAsyncFail(_ status: NabtoClientError, _ closure: @escaping (NabtoEdgeClientError) -> ()) {
        // Do not invoke user callback in same callstack. Use a background queue (vs main) as caller can have no
        // expectations about callback should happen on main thread; under normal circumstances, callback would happen
        // in a thread started by the native client SDK.
        DispatchQueue.global().async {
            let ec = Self.mapSimpleApiStatusToErrorCode(status)
            closure(ec)
        }
    }
    
    @available(iOS 13.0, *)
    func invokeAsync2(owner: Any,
                      connectionForErrorMessage: Connection?,
                      implClosure: (OpaquePointer) -> ()) async throws {
        let future: OpaquePointer = nabto_client_future_new(client.nativeClient)
        implClosure(future)
        let w = CallbackWrapper(debugDescription: "Helper.invokeAsync2", future: future, owner: owner, connectionForErrorMessage: connectionForErrorMessage)
        try await withCheckedThrowingContinuation { continuation in
            let status: NabtoClientError = w.registerCallback { ec in
                if ec == .OK {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ec)
                }
            }
            if status != NABTO_CLIENT_EC_OK {
                continuation.resume(throwing: Self.mapSimpleApiStatusToErrorCode(status))
            }
        }
    }
}

