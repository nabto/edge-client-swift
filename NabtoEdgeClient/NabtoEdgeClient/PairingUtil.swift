//
// Created by Ulrik Gammelby on 23/02/2022.
//

import Foundation
import SwiftCBOR

public enum PairingError: Error, Equatable {
    case INVALID_USERNAME
    case USERNAME_EXISTS
    case AUTHENTICATION_ERROR
    case LOCAL_PAIRING_ATTEMPTED_REMOTE
    case PAIRING_MODE_DISABLED
    case API_ERROR(cause: NabtoEdgeClientError)
    case FAILED
}

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

    static public func pair(connection: Connection, usingPairingString: String) {
        // todo parse string and invoke appropriate pairing function
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-local-open.html
    static public func pairLocalOpen(connection: Connection, desiredUsername: String) throws {
        let json: [String:String] = ["Username": desiredUsername]
        let cbor = CBOR.encode(json)
//        201: Pairing completed successfully.
//        201: Already paired.
//        400: Bad request (likely invalid username).
//        403: Blocked by IAM configuration.
//        404: Pairing mode disabled.
//        409: Username exists.
        do {
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/local-open")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: Data(cbor))
            let response = try! coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_USERNAME
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            if let pairingError = error as? PairingError {
                throw pairingError
            } else if let apiError = error as? NabtoEdgeClientError {
                throw PairingError.API_ERROR(cause: apiError)
            } else {
                throw PairingError.FAILED
            }
        }
    }

    static public func pairLocalInitial(connection: Connection) {
        // todo invoke CoAP POST /iam/pairing/local-initial
    }

    // https://docs.nabto.com/developer/api-reference/coap/iam/pairing-password-open.html
    static public func pairPasswordOpen(connection: Connection, desiredUsername: String, password: String) throws {
        let json: [String:String] = ["Username": desiredUsername]
        let cbor = CBOR.encode(json)
//        201: Pairing completed successfully.
//        201: Already paired.
//        400: Bad request (likely invalid username).
//        401: Missing password authentication. (not possible as impl always auths first)
//        403: Blocked by IAM configuration.
//        404: Pairing mode disabled. (not possible as we always password authenticate first and this would fail with auth error if disabled)
//        409: Username exists.
        do {
            try connection.passwordAuthenticate(username: "", password: password)
            let coap = try connection.createCoapRequest(method: "POST", path: "/iam/pairing/password-open")
            try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: Data(cbor))
            let response = try! coap.execute()
            switch (response.status) {
            case 201: break
            case 400: throw PairingError.INVALID_USERNAME
            case 401: throw PairingError.FAILED                // never here
            case 403: throw PairingError.PAIRING_MODE_DISABLED
            case 404: throw PairingError.PAIRING_MODE_DISABLED // never here
            case 409: throw PairingError.USERNAME_EXISTS
            default: throw PairingError.FAILED
            }
        } catch {
            if let pairingError = error as? PairingError {
                throw pairingError
            } else if let apiError = error as? NabtoEdgeClientError {
                if (apiError == .UNAUTHORIZED) {
                    throw PairingError.AUTHENTICATION_ERROR
                } else {
                    throw PairingError.API_ERROR(cause: apiError)
                }
            } else {
                throw PairingError.FAILED
            }
        }
    }

    static public func pairPasswordInvite(connection: Connection, invitedUser: String, password: String) throws {
        try connection.passwordAuthenticate(username: invitedUser, password: password)
        // todo invoke CoAP POST /iam/pairing/password-invite
    }

    static public func isCurrentUserPaired(connection: Connection) throws -> Bool {
//        205: On success.
//        404: The client is not paired.
        do {
            let coap = try connection.createCoapRequest(method: "GET", path: "/iam/me")
            let response = try! coap.execute()
            return response.status == 205
        } catch {
            // todo
        }

        // todo CoAP GET /iam/me .status == 205 ?
        return false
    }

    static public func getCurrentUser(connection: Connection) throws -> User {
        // todo CoAP GET /iam/me
        return User(username: "foo", displayName: "bar", fingerprint: "baz", sct: "qux", role: "zyx")
    }

    static public func getAvailablePairingModes(connection: Connection) throws -> [PairingMode] {
        // todo CoAP GET /iam/pairing
        return []
    }

}
