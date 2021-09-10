//
// Created by Ulrik Gammelby on 05/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

/* TODO nabtodoc
 * Connection events.
 *
 * Listen for these using `addConnectionEventsListener()` on a Connection object.
 */
@objc public enum NabtoEdgeClientConnectionEvent: Int {
    case CONNECTED
    case CLOSED
    case CHANNEL_CHANGED
    case UNEXPECTED_EVENT
}

/**
 * This protocol specifies a callback function to receive Connection events.
 */
@objc public protocol ConnectionEventReceiver {
    /*
     * The implementation is invoked when a connection event occurs.
     *
     * Supported events:
     * ```
     *  .CONNECTED          // connection established
     *  .CLOSED             // connection closed
     *  .CHANNEL_CHANGED    // connection type changed, e.g. upgrade from relay to p2p
     *  .UNEXPECTED_EVENT   // unexpected
     * ```
     * @param event The callback event.
     */
    func onEvent(event: NabtoEdgeClientConnectionEvent)
}

internal protocol NativeConnectionWrapper {
    var nativeConnection: OpaquePointer { get }
}

/**
 * This class represents a connection to a specific Nabto Edge device.
 *
 * Instances are created using `NabtoEdgeClient.createConnection()`.
 */
public class Connection: NSObject, NativeConnectionWrapper {
    internal let nativeConnection: OpaquePointer
    private let client: Client
    private let helper: Helper
    private var apiEventCallBackRegistered: Bool = false
    private var connectionEventListener: ConnectionEventListener? = nil

    internal init(client: Client) throws {
        let p = nabto_client_connection_new(client.nativeClient)
        if (p != nil) {
            self.nativeConnection = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        // keep a swift level reference to client (ie to NativeClientWrapper instance vs raw OpaquePointer) to prevent client
        // from being freed by ARC if owning app only keeps reference to connection
        self.client = client
        self.helper = Helper(nabtoClient: self.client)
        super.init()
    }

    deinit {
        nabto_client_connection_free(self.nativeConnection)
    }

    /**
     * Establish a connection synchronously.
     *
     * When the function returns, the connection is established and can be used with CoAP requests,
     * streams and tunnels.
     *
     * @throws UNAUTHORIZED if the authentication options do not match the basestation configuration
     * for this
     * @throws TOKEN_REJECTED if the basestation could not validate the specified token
     * @throws NO_CHANNELS if all parameters input were accepted but a connection could not be
     * established. Details about what went wrong are available as the
     * associated remoteError.
     * @throws NO_CHANNELS.remoteError.NOT_ATTACHED if the target remote device is not attached to the basestation
     * @throws NO_CHANNELS.remoteError.FORBIDDEN if the basestation request is rejected
     * @throws NO_CHANNELS.remoteError.NONE if remote relay was not enabled
     * @throws NO_CHANNELS.localError.NONE if mDNS discovery was not enabled
     */
    public func connect() throws {
        let status = self.helper.waitNoThrow { future in
            nabto_client_connection_connect(self.nativeConnection, future)
        }
        if (status == NABTO_CLIENT_EC_NO_CHANNELS) {
            throw Helper.createConnectionError(connection: self)
        } else {
            try Helper.throwIfNotOk(status)
        }
    }

    /**
     * Establish this connection asynchronously.
     *
     * The specified AsyncStatusReceiver closure is invoked with an error if an error occurs, see
     * the `connect()` function for details about error codes.
     *
     * @param closure Invoked when the connect attempt succeeds or fails.
     */
    public func connectAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: self) { future in
            nabto_client_connection_connect(self.nativeConnection, future)
        }
    }

    /**
     * Close this connection gracefully, ie send explicit close to the other peer. Blocks until the
     * connection is closed.
     *
     * @throws a NabtoEdgeClientError if an error occurs during close.
     */
    public func close() throws {
        try helper.wait { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }

    /**
     * Close this connection asynchronously.
     *
     * The specified AsyncStatusReceiver closure is
     * invoked with an error if an error occurs, see the `close()` function for details about
     * error codes.
     *
     * @param closure Invoked when the connect attempt succeeds or fails.
     */
    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }

    /**
     * Set connection options. Options must be set prior to invoking `connect()`.
     * @param json The JSON document with options to set
     * @throws INVALID_ARGUMENT if input is invalid
     */
    public func updateOptions(json: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_options(self.nativeConnection, json)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Password authenticate, do a password authentication exchange with a
     * device. Blocks until authentication attempt is complete.
     *
     * Password authenticate the client and the device. The password
     * authentication is bidirectional and based on PAKE, such that both
     * the client and the device learns that the other end knows the
     * password, without revealing the password to the other end.
     *
     * A specific use case for the password authentication is to prove the
     * identity of a device which identity is not already known, e.g. in a
     * pairing scenario.
     * @param username The username (note: use the empty string if using for Password Open Pairing, see https://docs.nabto.com/developer/guides/iam/pairing.html)
     * @param password The password (typically the open (global) or invite (per-user) pairing password)
     * @throws UNAUTHORIZED if the username or password is invalid
     * @throws NOT_FOUND if the password authentication feature is not available on the device
     * @throws NOT_CONNECTED if the connection is not open
     * @throws OPERATION_IN_PROGRESS if a password authentication request is already in progress on the connection
     * @throws TOO_MANY_REQUESTS if too many password attempts has been made
     */
    public func passwordAuthenticate(username: String, password: String) throws {
        try helper.wait { future in
            nabto_client_connection_password_authenticate(self.nativeConnection, username, password, future)
        }
    }


    /**
     * Password authenticate asynchronously, do a password authentication exchange with a
     * device.
     *
     * Password authenticate the client and the device. The password
     * authentication is bidirectional and based on PAKE, such that both
     * the client and the device learns that the other end knows the
     * password, without revealing the password to the other end.
     *
     * A specific use case for the password authentication is to prove the
     * identity of a device which identity is not already known, e.g. in a
     * pairing scenario.
     *
     * The specified AsyncStatusReceiver closure is invoked with an error if an error occurs, see
     * the `passwordAuthenticate()` function for details about error codes.
     * @param username The username (note: use the empty string if using for Password Open Pairing, see https://docs.nabto.com/developer/guides/iam/pairing.html)
     * @param password The password (typically the open (global) or invite (per-user) pairing password)
     */
    public func passwordAuthenticateAsync(username: String, password: String, closure: @escaping AsyncStatusReceiver) throws {
        try helper.invokeAsync(userClosure: closure, connection: self) { future in
            nabto_client_connection_password_authenticate(self.nativeConnection, username, password, future)
        }
    }

    /**
     * Get current representation of connection options.
     *
     * This is generally the same set of options as `updateOptions()` takes,
     * except that the private key is not exposed.
     * @throws FAILED if options could not be retrieved
     * @return the current options as a JSON string
     */
    public func getOptions() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_options(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    /**
     * Set the private key to be used on this connection.
     *
     * The private key is a PEM encoded string, it can be created by using the
     * `Client.createPrivateKey()` function or using another tool which can make an appropriate
     * private key (see https://docs.nabto.com/developer/guides/security/public_key_auth.html for
     * more info)
     *
     * @param key The PEM encoded private key to set.
     * @throws INVALID_STATE if the connection is not in the setup phase
     */
    public func setPrivateKey(key: String) throws {
        let status = nabto_client_connection_set_private_key(self.nativeConnection, key)
        return try Helper.throwIfNotOk(status)
    }

    /**
     * Get the full fingerprint of the remote device public key. The fingerprint is used to validate
     * the identity of the remote device.
     *
     * @throws INVALID_STATE if the connection is not established.
     * @return The fingerprint encoded as hex.
     */
    public func getDeviceFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_device_fingerprint_full_hex(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    /**
     * Get the fingerprint of the client public key used for this connection.
     * @throws INVALID_STATE if the connection is not established.
     * @return The fingerprint encoded as hex.
     */
    public func getClientFingerprintHex() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_connection_get_client_fingerprint_full_hex(self.nativeConnection, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    /**
     * Create a new stream on this connection. Stream must subsequently be opened.
     * @throws ALLOCATION_ERROR if the stream could not be created.
     */
    public func createStream() throws -> Stream {
        return try Stream(nabtoClient: self.client, nabtoConnection: self)
    }

    /**
     * Create a new CoAP request on this connection. Request must subsequently be executed.
     * @param method   The CoAP method (either `GET`. `POST`, `PUT` or `DELETE`)
     * @param path   The CoAP path (e.g., `/heatpump/temperature`)
     * @throws ALLOCATION_ERROR if the request could not be created.
     */
    public func createCoapRequest(method: String, path: String) throws -> CoapRequest {
        return try CoapRequest(nabtoClient: self.client, nabtoConnection: self, method: method, path: path)
    }

    /**
     * Create a new tunnel on this connection. Tunnel must subsequently be opened.
     * @throws ALLOCATION_ERROR if the tunnel could not be created.
     */
    public func createTcpTunnel() throws -> TcpTunnel {
        return try TcpTunnel(nabtoClient: self.client, nabtoConnection: self)
    }

    /**
     * Add a callback function to receive connection events.
     * @param cb An implementation of the ConnectionEventReceiver protocol
     * @throws INVALID_STATE if listener could not be added
     */
    public func addConnectionEventsReceiver(cb: ConnectionEventReceiver) throws {
        if (self.connectionEventListener == nil) {
            self.connectionEventListener = try ConnectionEventListener(nabtoConnection: self, nabtoClient: self.client)
        }
        try self.connectionEventListener!.addUserCb(cb)
    }

    /**
     * Remove a callback function to receive connection events.
     * @param cb An implementation of the ConnectionEventReceiver protocol
     */
    public func removeConnectionEventsReceiver(cb: ConnectionEventReceiver) {
        guard let listener = self.connectionEventListener else {
            return
        }
        listener.removeUserCb(cb)
    }

}
