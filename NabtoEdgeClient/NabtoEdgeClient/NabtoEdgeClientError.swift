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

    case ALLOCATION_ERROR
    case CONNECTION_REFUSED
    case DNS
    case EOF
    case FORBIDDEN
    case INVALID_ARGUMENT
    case INVALID_STATE           // did you set private key on connection? is connection open before invoking coap?
    case NONE
    case NOT_ATTACHED            // device not running or has no internet connection (and you are on a remote net)
    case NOT_CONNECTED
    case NOT_FOUND

    // not possible to establish connection to requested device either locally or remotely,
    // detailed reason in localError / remoteError parameters
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
