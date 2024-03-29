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

/* TODO nabtodoc
 * Connection types.
 *
 * Get the type using `getType()` on a Connection object.
 */
@objc public enum NabtoEdgeClientConnectionType: Int {
    case RELAY
    case DIRECT
}


/**
 * This protocol specifies a callback function to receive Connection events.
 */
@objc public protocol ConnectionEventReceiver {
    /**
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
    var nativeConnection: OpaquePointer {
        get
    }
}

public class ConnectionOptions : Codable {
    var PrivateKey: String?
    var ProductId: String?
    var DeviceId: String?
    var ServerUrl: String?
    var ServerKey: String?
    var ServerJwtToken: String?
    var ServerConnectToken: String?
    var AppName: String?
    var AppVersion: String?
    var KeepAliveInterval: Int?
    var KeepAliveRetryInterval: Int?
    var KeepAliveMaxRetries: Int?
    var DtlsHelloTimeout: Int?
    var Local: Bool?
    var Remote: Bool?
    var Rendezvous: Bool?
    var ScanLocalConnect: Bool?
}

/**
 * This class represents a connection to a specific Nabto Edge device. The Connection object must
 * be kept alive for the duration of all streams, tunnels, and CoAP sessions created from it.
 *
 * Instances are created using `NabtoEdgeClient.createConnection()`.
 */
public class Connection: NSObject, NativeConnectionWrapper {
    internal let nativeConnection: OpaquePointer
    private let client: ClientImpl
    private let helper: Helper
    private var apiEventCallBackRegistered: Bool = false
    internal var connectionEventListener: ConnectionEventListener? = nil
    private let clientPointerForDebugOutput: OpaquePointer

    internal init(client: ClientImpl) throws {
        if let p = nabto_client_connection_new(client.nativeClient) {
            self.clientPointerForDebugOutput = client.nativeClient
            self.nativeConnection = p
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        self.client = client
        self.helper = Helper(client: client)
        super.init()
    }

    deinit {
        if let listener = self.connectionEventListener {
            listener.stop()
        }
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
     * @throws STOPPED if the client instance was stopped
     * @throws NO_CHANNELS if all parameters input were accepted but a connection could not be
     * established. Details about what went wrong are available as the
     * associated localError and remoteError.
     * @throws NO_CHANNELS.remoteError.NOT_ATTACHED if the target remote device is not attached to the basestation
     * @throws NO_CHANNELS.remoteError.FORBIDDEN if the basestation request is rejected
     * @throws NO_CHANNELS.remoteError.NONE if remote relay was not enabled
     * @throws NO_CHANNELS.localError.NONE if mDNS discovery was not enabled
     * @throws NO_CHANNELS.localError.NOT_FOUND if no local device was found
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
        self.helper.invokeAsync(userClosure: closure, owner: self, connectionForErrorMessage: self) { future in
            nabto_client_connection_connect(self.nativeConnection, future)
        }
    }
    
    /**
     * Establish a connection asynchronously using Swift concurrency..
     *
     * When the function returns, the connection is established and can be used with CoAP requests,
     * streams and tunnels.
     *
     * @throws UNAUTHORIZED if the authentication options do not match the basestation configuration
     * for this
     * @throws TOKEN_REJECTED if the basestation could not validate the specified token
     * @throws STOPPED if the client instance was stopped
     * @throws NO_CHANNELS if all parameters input were accepted but a connection could not be
     * established. Details about what went wrong are available as the
     * associated localError and remoteError.
     * @throws NO_CHANNELS.remoteError.NOT_ATTACHED if the target remote device is not attached to the basestation
     * @throws NO_CHANNELS.remoteError.FORBIDDEN if the basestation request is rejected
     * @throws NO_CHANNELS.remoteError.NONE if remote relay was not enabled
     * @throws NO_CHANNELS.localError.NONE if mDNS discovery was not enabled
     * @throws NO_CHANNELS.localError.NOT_FOUND if no local device was found
     */
    @available(iOS 13.0, *)
    public func connectAsync() async throws {
        try await self.helper.invokeAsync(owner: self, connectionForErrorMessage: self) { future in
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
     * @param closure Invoked when the close succeeds or fails.
     */
    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, owner: self, connectionForErrorMessage: nil) { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }
    
    /**
     * Close this connection asynchronously.
     *
     * @throws a NabtoEdgeClientError if an error occurs during close.
     */
    @available(iOS 13.0, *)
    public func closeAsync() async throws {
        try await self.helper.invokeAsync(owner: self, connectionForErrorMessage: nil) { future in
            nabto_client_connection_close(self.nativeConnection, future)
        }
    }

    /**
     * Stop pending connect or close on a connection.
     *
     * After stop has been called the connection should not be used any more.
     *
     * Stop can be used if the user cancels a connect/close request.
     */
    public func stop() {
        nabto_client_connection_stop(self.nativeConnection)
    }

    /**
     * Set connection options. Options must be set prior to invoking `connect()`.
     * @param options The options to set
     * @throws INVALID_ARGUMENT if input is invalid
     */
    public func updateOptions(options: ConnectionOptions) throws {
        let encoder = JSONEncoder()
        let json: Data
        do {
            json = try encoder.encode(options)
        } catch {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "json encoding error: \(error))")
        }

        let str = String(data: json, encoding: .utf8)
        if let str = str {
            try self.updateOptions(json: str)
        } else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "json encoding error")
        }
    }

    /**
     * Set connection options. Options must be set prior to invoking `connect()`. This allows setting all the
     * individual options available through the setXyz() functions (e.g., setPrivateKey()).
     * @param json The JSON document with options to set
     * @throws INVALID_ARGUMENT if input is invalid
     */
    public func updateOptions(json: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_options(self.nativeConnection, json)
        try Helper.throwIfNotOk(status)
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
     * Set the product id of the device to connect to.
     * @param key The product id of the target device.
     * @throws INVALID_STATE if connection already established
     */
    public func setProductId(id: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_product_id(self.nativeConnection, id)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Set the device id of the device to connect to.
     * @param key The device id of the target device.
     * @throws INVALID_STATE if connection already established
     */
    public func setDeviceId(id: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_device_id(self.nativeConnection, id)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Set the server key associated with this client application through the Nabto Cloud Console.
     * @param key The server key to use.
     * @throws INVALID_STATE if connection already established
     */
    public func setServerKey(key: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_server_key(self.nativeConnection, key)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Set a server connect token for use with this connection for establishing a remote connection (if the authentication
     * type for the application associated with this client is set to "SCT" in the Nabto Cloud Console). The SCT must be
     * shared with the target device, typically setup in the pairing step.
     * @param key The SCT to use for this connection.
     * @throws INVALID_STATE if connection already established
     */
    public func setServerConnectToken(sct: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_server_connect_token(self.nativeConnection, sct)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Set a JWT for use with this connection for establishing a remote connection (if the authentication
     * type for the application associated with this client is set to "JWT" in the Nabto Cloud Console).
     * @param key The token to use for this connection.
     * @throws INVALID_STATE if connection already established
     */
    public func setServerJwtToken(jwt: String) throws {
        let status: NabtoClientError = nabto_client_connection_set_server_jwt_token(self.nativeConnection, jwt)
        try Helper.throwIfNotOk(status)
    }

    /**
     * Do a password authentication exchange with a device. Blocks until authentication attempt is complete.
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
     * @param username The username (note: use the empty string if using for Password Open Pairing, see https://docs.nabto.com/developer/guides/iam/pairing.html)
     * @param password The password (typically the open (global) or invite (per-user) pairing password)
     * @throws UNAUTHORIZED if the username or password is invalid
     * @throws NOT_FOUND if the password authentication feature is not available on the device
     * @throws NOT_CONNECTED if the connection is not open
     * @throws OPERATION_IN_PROGRESS if a password authentication request is already in progress on the connection
     * @throws TOO_MANY_REQUESTS if too many password attempts has been made
     * @throws STOPPED if the client is stopped
     */
    public func passwordAuthenticate(username: String, password: String) throws {
        try helper.wait { future in
            nabto_client_connection_password_authenticate(self.nativeConnection, username, password, future)
        }
    }

    /**
     * Do an asynchronous password authentication exchange with a device.
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
     *
     * @param username The username (note: use the empty string if using for Password Open Pairing, see https://docs.nabto.com/developer/guides/iam/pairing.html)
     * @param password The password (typically the open (global) or invite (per-user) pairing password)
     * @param closure Invoked when authentication is completed or an error occurs
     */
    public func passwordAuthenticateAsync(username: String, password: String, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, owner: self, connectionForErrorMessage: self) { future in
            nabto_client_connection_password_authenticate(self.nativeConnection, username, password, future)
        }
    }

    /**
     * Do an asynchronous password authentication exchange with a device.
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
     * @param username The username (note: use the empty string if using for Password Open Pairing, see https://docs.nabto.com/developer/guides/iam/pairing.html)
     * @param password The password (typically the open (global) or invite (per-user) pairing password)
     * @throws UNAUTHORIZED if the username or password is invalid
     * @throws NOT_FOUND if the password authentication feature is not available on the device
     * @throws NOT_CONNECTED if the connection is not open
     * @throws OPERATION_IN_PROGRESS if a password authentication request is already in progress on the connection
     * @throws TOO_MANY_REQUESTS if too many password attempts has been made
     * @throws STOPPED if the client is stopped
     */
    @available(iOS 13.0, *)
    public func passwordAuthenticateAsync(username: String, password: String) async throws {
        try await self.helper.invokeAsync(owner: self, connectionForErrorMessage: self) { future in
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
     * Get the type of this connection.
     *
     * Note that the type may change. All remote connections start out as relay connections. Listen for
     * ConnectionEvents using addConnectionEventsReceiver to get notified if the type changes.
     *
     * Possible values:
     * ```
     *  .RELAY          // relay through the basestation
     *  .DIRECT         // directly connected
     * ```
     * @throws NOT_CONNECTED if the connection is not yet established
     * @throws STOPPED if the connection is stopped
     * @throws FAILED_WITH_DETAIL if an unexpected connection type was returned by the underlying API
     * @return the connection type (.RELAY or .DIRECT)
     */
    public func getType() throws -> NabtoEdgeClientConnectionType {
        var type: NabtoClientConnectionType = NABTO_CLIENT_CONNECTION_TYPE_RELAY
        let status = nabto_client_connection_get_type(self.nativeConnection, &type)
        switch (type) {
        case NABTO_CLIENT_CONNECTION_TYPE_RELAY: return .RELAY
        case NABTO_CLIENT_CONNECTION_TYPE_DIRECT: return .DIRECT
        default: throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Unexpected connection type \(type.rawValue)")
        }
    }

    /**
     * Create a new stream on this connection. Stream must subsequently be opened.
     * The returned Stream object must be kept alive while in use.
     *
     * @throws ALLOCATION_ERROR if the stream could not be created.
     */
    public func createStream() throws -> Stream {
        return try Stream(client: client, connection: self)
    }

    /**
     * Create a new CoAP request on this connection. Request must subsequently be executed.
     * The returned CoapRequest object must be kep alive while in use.
     *
     * @param method   The CoAP method (either `GET`. `POST`, `PUT` or `DELETE`)
     * @param path   The CoAP path (e.g., `/heatpump/temperature`)
     * @throws ALLOCATION_ERROR if the request could not be created.
     */
    public func createCoapRequest(method: String, path: String) throws -> CoapRequest {
        return try CoapRequest(client: client, connection: self, method: method, path: path)
    }

    /**
     * Create a new tunnel on this connection. Tunnel must subsequently be opened.
     * The returned TcpTunnel object must be kept alive while in use.
     *
     * @throws ALLOCATION_ERROR if the tunnel could not be created.
     */
    public func createTcpTunnel() throws -> TcpTunnel {
        return try TcpTunnel(client: client, connection: self)
    }

    /**
     * Add a callback function to receive connection events.
     * @param cb An implementation of the ConnectionEventReceiver protocol
     * @throws INVALID_STATE if listener could not be added
     */
    public func addConnectionEventsReceiver(cb: ConnectionEventReceiver) throws {
        if (self.connectionEventListener == nil) {
            self.connectionEventListener = ConnectionEventListener(client: self.client, connection: self)
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
        if (!listener.hasUserCbs()) {
            self.connectionEventListener = nil
        }
    }

}
