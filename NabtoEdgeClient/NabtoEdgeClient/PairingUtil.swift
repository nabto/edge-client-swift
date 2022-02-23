//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import NabtoEdgeClient


class PairingUtil {

    public struct User {
        let username: String
        let displayName: String
        let fingerprint: String
        let sct: String
        let role: String

        init(username: String, displayName: String, fingerprint: String, sct: String, role: String) {
            self.username = username
            self.displayName = displayName
            self.fingerprint = fingerprint
            self.sct = sct
            self.role = role
        }
    }

    public enum PairingMode {
        case LocalOpen
        case LocalInitial
        case PasswordOpen
        case PasswordInvite
    }

    private let connection: Connection

    init(connection: Connection) {
        self.connection = connection
    }

    public func attemptBestPossiblePairing(username: String?, password: String?) throws {
        // todo based on the user's input and the available pairing modes on the device, try the best pairing mode:
        //   if username and password specified, try to authenticate and password-invite pair
        //   else if password specified and password open pairing is available, try password open pairing
        //   else if username specified and connection is local (query type - how?? todo!) and local open pairing is available, try local open pairing
        //   else if connection is local (query type - how?? todo!) and local initial pairing is available, try local initial pairing
        //   else fail
    }

    public func pair(usingPairingString: String) {
        // todo parse string and invoke appropriate pairing function
    }

    public func pairLocalOpen(desiredUsername: String) {
        // todo invoke CoAP POST /iam/pairing/local-open
    }

    public func pairLocalInitial() {
        // todo invoke CoAP POST /iam/pairing/local-initial
    }

    public func pairPasswordOpen(desiredUsername: String, password: String) throws {
        try self.connection.passwordAuthenticate(username: "", password: password)
        // todo invoke CoAP POST /iam/pairing/password-open
    }

    public func pairPasswordInvite(invitedUser: String, password: String) throws {
        try self.connection.passwordAuthenticate(username: invitedUser, password: password)
        // todo invoke CoAP POST /iam/pairing/password-invite
    }

    public func isCurrentUserPaired() throws -> Bool {
        // todo CoAP GET /iam/me .status == 205 ?
        return false
    }

    public func getCurrentUser() throws -> User {
        // todo CoAP GET /iam/me
        return User(username: "foo", displayName: "bar", fingerprint: "baz", sct: "qux", role: "zyx")
    }

    public func getAvailablePairingModes() throws -> [PairingMode] {
        // todo CoAP GET /iam/pairing
        return []
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func authenticate(username: String, password: String) throws {
    }
}
