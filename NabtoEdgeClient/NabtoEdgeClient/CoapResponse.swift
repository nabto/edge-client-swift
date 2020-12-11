//
// Created by Ulrik Gammelby on 01/09/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

/**
 * This class encapsulates a CoAP response, resulting from executing a CoapRequest.
 */
public class CoapResponse {

    /**
     * The CoAP response status, e.g. 205 for GET success and 404 for resource not found.
     */
    public let status: UInt16

    /**
     * The CoAP response content format.
     */
    public let contentFormat: UInt16!

    /**
     * The CoAP payload, set if the status indicates such.
     */
    public let payload: Data!

    internal init(_ coap: OpaquePointer) throws {
        var uint16Result: UInt16 = 0
        var ec = nabto_client_coap_get_response_status_code(coap, &uint16Result)
        try Helper.throwIfNotOk(ec)
        self.status = uint16Result

        guard (uint16Result >= 200 && uint16Result < 300) else {
            self.contentFormat = nil
            self.payload = nil
            return
        }

        ec = nabto_client_coap_get_response_content_format(coap, &uint16Result)
        try Helper.throwIfNotOk(ec)
        self.contentFormat = uint16Result

        var payload: UnsafeMutableRawPointer?
        var length: Int = 0
        let status = nabto_client_coap_get_response_payload(coap, &payload, &length)
        try Helper.throwIfNotOk(status)
        self.payload = Data(bytes: payload!, count: length)
    }
}
