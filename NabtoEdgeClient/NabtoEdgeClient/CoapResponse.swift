//
// Created by Ulrik Gammelby on 01/09/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public class CoapResponse {

    public let status: UInt16
    public var contentFormat: UInt16!
    public var payload: Data!

    init(_ coap: OpaquePointer) throws {
        var uint16Result: UInt16 = 0
        var ec = nabto_client_coap_get_response_status_code(coap, &uint16Result)
        try Helper.throwIfNotOk(ec)
        self.status = uint16Result

        guard (self.status >= 200 && self.status < 300) else {
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