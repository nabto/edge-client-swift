//
//  NabtoEdgeClientError.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 1/6/21.
//  Copyright © 2021 Nabto. All rights reserved.
//

import Foundation

/*
 * Error codes directly mapped from the underlying core SDK.
 */
public indirect enum NabtoEdgeClientError: Error, Equatable {
    case OK

    case ABORTED
    case ALLOCATION_ERROR
    case CONNECTION_REFUSED
    case DNS
    case EOF
    case FORBIDDEN
    case INVALID_ARGUMENT
    case INVALID_STATE
    case NONE
    case NOT_ATTACHED
    case NOT_CONNECTED
    case NOT_FOUND
    case NO_CHANNELS(localError: NabtoEdgeClientError, remoteError: NabtoEdgeClientError)
    case NO_DATA
    case OPERATION_IN_PROGRESS
    case STOPPED
    case TIMEOUT
    case TOKEN_REJECTED
    case UNAUTHORIZED
    case UNKNOWN_DEVICE_ID
    case UNKNOWN_PRODUCT_ID
    case UNKNOWN_SERVER_KEY

    case FAILED

    case UNEXPECTED_API_STATUS
}
