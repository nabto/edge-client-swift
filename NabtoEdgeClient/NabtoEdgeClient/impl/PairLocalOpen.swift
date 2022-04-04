//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairLocalOpen {

    let connection: Connection
    let method = "POST"
    let path = "/iam/pairing/local-open"
    let desiredUsername: String

    init(_ connection: Connection, _ desiredUsername: String) {
        self.connection = connection
        self.desiredUsername = desiredUsername
    }

    internal func execute() throws {
        let cbor = try PairingUser(username: self.desiredUsername).encode()
        do {
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/local-open")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            let response = try coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_INPUT
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            try PairingHelper.rethrowPairingError(error)
        }
    }

}