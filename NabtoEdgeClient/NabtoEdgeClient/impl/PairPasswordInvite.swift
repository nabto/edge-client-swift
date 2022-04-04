//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairPasswordInvite {

    let connection: Connection
    let username: String
    let password: String
    let method = "POST"
    let path = "/iam/pairing/password-invite"

    init(connection: Connection, username: String, password: String) throws {
        self.connection = connection
        self.username = username
        self.password = password
    }

    internal func execute() throws {
        // TODO apply template method pattern
        try PairingHelper.invokePasswordBasedPairing(
                connection: connection,
                path: self.path,
                username: self.username,
                password: self.password)
    }
}
