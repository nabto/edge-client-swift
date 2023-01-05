//
//  NabtoEdgeClientError.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 1/6/21.
//  Copyright © 2021 Nabto. All rights reserved.
//

import Foundation

/**
 * Error codes directly mapped from the underlying core SDK.
 */
public indirect enum NabtoEdgeClientError: Error, Equatable {
    /**
     * Operation completed successfully.
     */
    case OK

    /**
     * Resources could not be allocated, e.g. out of memory.
     */
    case ALLOCATION_ERROR

    /**
     * The client could not connect to the basestation.
     */
    case CONNECTION_REFUSED

    /**
     * DNS could not be resolved.
     */
    case DNS

    /**
     * Stream EOF has been reached.
     */
    case EOF

    /**
     * The basestation or target device rejected a request.
     */
    case FORBIDDEN

    /**
     * Specified input was invalid.
     */
    case INVALID_ARGUMENT

    /**
     * The object on which an operation was invoked was not in a valid state for that operation.
     *
     * This could e.g. occur if a private key was not set prior to opening a connection.
     */
    case INVALID_STATE

    /**
     * If nothing is available for the given request.
     *
     * If for instance the error code for the local channel is requested but no local channel was ever established.
     */
    case NONE

    /**
     * The target device is not attached to the basestation, ie the device is offline.
     *
     * So the target device is not running or has no internet connection (and you are on a remote net)
     */
    case NOT_ATTACHED

    /**
     * An operation was attempted that requires an open connection.
     *
     * If for instance a stream is opened or a CoAP request is executed on a connection that is not yet opened.
     */
    case NOT_CONNECTED

    /**
     * Some requested object or feature was not found.
     *
     * For instance, if no devices are found with an mDNS scan. Or if password authentication is attempted towards
     * a device that does not support password authentication. Or if a tunnel service is requested that is not
     * configured on the device.
     */
    case NOT_FOUND

    // not possible to establish connection to requested device either locally or remotely,
    // detailed reason in localError / remoteError parameters

    /**
     * It was not possible to establish a local or remote connection to the target device.
     *
     * Details are provided about what went wrong with the local and remote connect attempts, respectively.
     */
    case NO_CHANNELS(localError: NabtoEdgeClientError, remoteError: NabtoEdgeClientError)

    /**
     * No data is available for the given request.
     */
    case NO_DATA

    /**
     * A conflicting operation is already in progress.
     */
    case OPERATION_IN_PROGRESS

    /**
     * The object was stopped and cannot complete the requested operation.
     */
    case STOPPED

    /**
     * The request timed out.
     */
    case TIMEOUT

    /**
     * The basestation rejected the specified token.
     */
    case TOKEN_REJECTED

    /**
     * If the client could not be authorized for the given operation.
     */
    case UNAUTHORIZED

    /**
     * The specified device id is not known by the basestation.
     */
    case UNKNOWN_DEVICE_ID

    /**
     * The specified product id is not known by the basestation.
     */
    case UNKNOWN_PRODUCT_ID

    /**
     * The specified server key is not known by the basestation.
     */
    case UNKNOWN_SERVER_KEY

    /**
     * An unknown error occurred in the underlying SDK.
     */
    case API_UNKNOWN_ERROR

    /**
     * Too many failed password authentication attempts.
     */
    case TOO_MANY_WRONG_PASSWORD_ATTEMPTS

    /**
     * Requested TCP tunnel port is already in use by another process on the system.
     */
    case PORT_IN_USE

    /**
     * Something unspecified failed.
     */
    case FAILED

    /**
     * The operation failed, the detailed error is provided.
     */
    case FAILED_WITH_DETAIL(detail: String)

    /**
     * The underlying API returned an unexpected error code.
     */
    case UNEXPECTED_API_STATUS
}
