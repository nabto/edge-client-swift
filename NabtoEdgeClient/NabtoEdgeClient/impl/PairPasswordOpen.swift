//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairPasswordOpen {

    let connection: Connection
    let desiredUsername: String
    let password: String
    let method = "POST"
    let path = "/iam/pairing/password-open"

    init(connection: Connection, desiredUsername: String, password: String) throws {
        self.connection = connection
        self.desiredUsername = desiredUsername
        self.password = password
    }

    internal func execute() throws {
        // TODO apply template method pattern
        let cbor = try PairingUser(username: self.desiredUsername).encode()
        try PairingHelper.invokePasswordBasedPairing(
                connection: self.connection,
                path: self.path,
                username: "",
                password: self.password,
                data: cbor
        )
    }
}