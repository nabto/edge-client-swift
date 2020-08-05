//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

internal class Helper {
    internal static func throwIfNotOk(_ status: NabtoClientError?) throws {
        if (status == nil) {
            throw NabtoEdgeClientError.UNEXPECTED_API_STATUS
        }
        switch (status) {
        case NABTO_CLIENT_EC_OK: return
        case NABTO_CLIENT_EC_INVALID_STATE: throw NabtoEdgeClientError.INVALID_STATE
        case NABTO_CLIENT_EC_INVALID_ARGUMENT: throw NabtoEdgeClientError.INVALID_ARGUMENT
        case NABTO_CLIENT_EC_NO_DATA: throw NabtoEdgeClientError.NO_DATA
        default:
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
}