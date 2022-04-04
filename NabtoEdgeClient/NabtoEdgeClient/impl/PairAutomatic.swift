//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal class PairAutomatic {

    let client: Client
    let options: ConnectionOptions
    let pairingString: String?
    let desiredUsername: String?

    init(client: Client,
         opts: ConnectionOptions,
         pairingString: String?=nil,
         desiredUsername: String?=nil) {
        self.client = client
        self.options = opts
        self.pairingString = pairingString
        self.desiredUsername = desiredUsername
    }

    internal func execute() throws -> Connection {
        var password: String!
        if let pairingString = self.pairingString {
            let elements = pairingString.components(separatedBy: ",")
            for element in elements {
                let tuple = element.components(separatedBy: "=")
                let key = tuple[0]
                let value = tuple[1]
                switch (key) {
                case "p": self.options.ProductId = value; break
                case "d": options.DeviceId = value; break
                case "pwd": password = value; break
                case "sct": options.ServerConnectToken = value; break
                default: throw PairingError.INVALID_PAIRING_STRING(error: "unexpected element \(key)")
                }
            }
            if (self.options.ProductId == nil || self.options.DeviceId == nil || password == nil || self.options.ServerConnectToken == nil) {
                throw PairingError.INVALID_PAIRING_STRING(error: "missing element in pairing string")
            }
        }

        let connection = try client.createConnection()
        try connection.updateOptions(options: self.options)
        try connection.connect()

        do {
            try PairLocalInitial(connection).execute()
        } catch {
            if let desiredUsername = desiredUsername {
                do {
                    try PairLocalOpen(connection, desiredUsername).execute()
                } catch {
                    if let password = password {
                        try PairPasswordOpen(
                                connection: connection,
                                desiredUsername: desiredUsername,
                                password: password).execute()
                    }
                }
            }
        }

        return connection
    }
}