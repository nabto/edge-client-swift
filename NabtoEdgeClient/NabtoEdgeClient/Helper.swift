//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

internal class Helper {

    private let client: NativeClientWrapper

    init(nabtoClient: NativeClientWrapper) {
        self.client = nabtoClient
    }

    internal static func throwIfNotOk(_ status: NabtoClientError?) throws {
        if (status == nil) {
            throw NabtoEdgeClientError.UNEXPECTED_API_STATUS
        }
        switch (status) {
        case NABTO_CLIENT_EC_OK: return
        case NABTO_CLIENT_EC_ABORTED: throw NabtoEdgeClientError.ABORTED
        case NABTO_CLIENT_EC_EOF: throw NabtoEdgeClientError.EOF
        case NABTO_CLIENT_EC_FORBIDDEN: throw NabtoEdgeClientError.FORBIDDEN
        case NABTO_CLIENT_EC_INVALID_ARGUMENT: throw NabtoEdgeClientError.INVALID_ARGUMENT
        case NABTO_CLIENT_EC_INVALID_STATE: throw NabtoEdgeClientError.INVALID_STATE
        case NABTO_CLIENT_EC_NO_CHANNELS: throw NabtoEdgeClientError.NO_CHANNELS
        case NABTO_CLIENT_EC_NO_DATA: throw NabtoEdgeClientError.NO_DATA
        case NABTO_CLIENT_EC_NOT_CONNECTED: throw NabtoEdgeClientError.NOT_CONNECTED
        case NABTO_CLIENT_EC_NOT_FOUND: throw NabtoEdgeClientError.NOT_FOUND
        case NABTO_CLIENT_EC_OPERATION_IN_PROGRESS: throw NabtoEdgeClientError.OPERATION_IN_PROGRESS
        default:
            let str = String(cString: nabto_client_error_get_string(status!)!)
            let msg = String(cString: nabto_client_error_get_message(status!)!)
            NSLog("Unexpected API status \(str) (\(status!)): \(msg)")
            throw NabtoEdgeClientError.UNEXPECTED_API_STATUS
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


}