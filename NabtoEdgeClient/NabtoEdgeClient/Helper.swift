//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

// ensures client is kept alive until future is resolved
internal class CallbackWrapper : NSObject {
    let client: NativeClientWrapper
    let future: OpaquePointer
    let cb: AsyncStatusReceiver
    var cleanupClosure: (() -> Void)?

    init(client: NativeClientWrapper, future: OpaquePointer, cb: @escaping AsyncStatusReceiver) {
        self.client = client
        self.future = future
        self.cb = cb
        super.init()
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<CallbackWrapper>.fromOpaque(data!).takeUnretainedValue()
            mySelf.invokeUserCallback(ec)
        }, rawSelf)
    }

    func setCleanupClosure(cleanupClosure: @escaping () -> Void) {
        self.cleanupClosure = cleanupClosure
    }

    func invokeUserCallback(_ ec: NabtoClientError) {
        let wrapperError = Helper.mapApiStatusToErrorCode(ec)
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

    internal static func mapApiStatusToErrorCode(_ status: NabtoClientError) -> NabtoEdgeClientError {
        switch (status) {
        case NABTO_CLIENT_EC_OK: return NabtoEdgeClientError.OK
        case NABTO_CLIENT_EC_ABORTED: return NabtoEdgeClientError.ABORTED
        case NABTO_CLIENT_EC_EOF: return NabtoEdgeClientError.EOF
        case NABTO_CLIENT_EC_FORBIDDEN: return NabtoEdgeClientError.FORBIDDEN
        case NABTO_CLIENT_EC_INVALID_ARGUMENT: return NabtoEdgeClientError.INVALID_ARGUMENT
        case NABTO_CLIENT_EC_INVALID_STATE: return NabtoEdgeClientError.INVALID_STATE
        case NABTO_CLIENT_EC_NO_CHANNELS: return NabtoEdgeClientError.NO_CHANNELS
        case NABTO_CLIENT_EC_NO_DATA: return NabtoEdgeClientError.NO_DATA
        case NABTO_CLIENT_EC_NOT_CONNECTED: return NabtoEdgeClientError.NOT_CONNECTED
        case NABTO_CLIENT_EC_NOT_FOUND: return NabtoEdgeClientError.NOT_FOUND
        case NABTO_CLIENT_EC_OPERATION_IN_PROGRESS: return NabtoEdgeClientError.OPERATION_IN_PROGRESS
        case NABTO_CLIENT_EC_TIMEOUT: return NabtoEdgeClientError.TIMEOUT
        default: return .UNEXPECTED_API_STATUS
        }
    }

    internal static func throwIfNotOk(_ status: NabtoClientError?) throws {
        if (status == nil) {
            throw NabtoEdgeClientError.UNEXPECTED_API_STATUS
        }
        let error = mapApiStatusToErrorCode(status!)
        if (error != .OK) {
            throw error
        }
    }

    internal static func handleStringResult(status: NabtoClientError, cstring: UnsafeMutablePointer<Int8>?) throws -> String {
        try throwIfNotOk(status)
        if (cstring == nil) {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        let result = String(cString: cstring!)
        nabto_client_string_free(cstring)
        return result
    }

    internal func wait(closure: (OpaquePointer?) -> Void) throws {
        let future = nabto_client_future_new(self.client.nativeClient)
        closure(future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        try Helper.throwIfNotOk(status)
    }

    internal func futureCallback(closure: (OpaquePointer?) -> Void) throws {
        let future = nabto_client_future_new(self.client.nativeClient)
        closure(future)
        nabto_client_future_wait(future)
        let status = nabto_client_future_error_code(future)
        nabto_client_future_free(future)
        try Helper.throwIfNotOk(status)
    }

    internal func invokeAsync(userClosure: @escaping AsyncStatusReceiver, implClosure: (OpaquePointer) -> Void) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        implClosure(future)
        let w = CallbackWrapper(client: self.client, future: future, cb: userClosure)
        w.setCleanupClosure(cleanupClosure: {
            self.activeCallbacks.remove(w)}
        )
        self.activeCallbacks.insert(w)
    }




}