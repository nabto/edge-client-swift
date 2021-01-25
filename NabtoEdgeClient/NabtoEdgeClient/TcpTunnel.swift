//
// Created by Ulrik Gammelby on 26/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

/**
 * A Nabto Edge TCP tunnel allows tunnelling of tcp connections from a client to a device over a Nabto
 * connection. Under the hood, Nabto Streams are used to stream the data reliably.
 *
 * The client opens a TCP listener which listens for incoming TCP connections on the local
 * port. When a connection is accepted by the TCP listener, a new stream is created to the
 * device. When the stream is created on the device, the device opens a tcp connection to the
 * specified service. Once this connection is opened TCP data flows from the TCP Client on the
 * client side to the TCP Server on the device side.
 *
 * Tunnel instances are created using `Connection.createTcpTunnel()`.
 */
public class TcpTunnel {

    private let connection: NativeConnectionWrapper
    private let client: Client
    private let tunnel: OpaquePointer
    private let helper: Helper
    private var activeCallbacks: Set<CallbackWrapper> = Set<CallbackWrapper>()

    internal init(nabtoClient: Client, nabtoConnection: Connection) throws {
        self.client = nabtoClient
        self.connection = nabtoConnection
        self.helper = Helper(nabtoClient: self.client)
        let p = nabto_client_tcp_tunnel_new(self.connection.nativeConnection)
        if (p != nil) {
            self.tunnel = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
    }

    deinit {
        nabto_client_tcp_tunnel_free(self.tunnel)
    }

    /**
     * Open this tunnel. Blocks until the tunnel is ready to use or an error occurs.
     *
     * @param service The service to connect to on the remote device (as defined in the device's
     * configuration), e.g. "http", "http-admin", "ssh", "rtsp".
     * @param localPort The local port to listen on. If 0 is specified, an ephemeral port is used,
     * it can be retrieved with `getLocalPort()`.
     * @throws NABTO_CLIENT_EC_NOT_FOUND if requesting an unknown service.
     * @throws NABTO_CLIENT_EC_FORBIDDEN if target device did not allow opening a tunnel to specified service for the current client
     */
    public func open(service: String, localPort: UInt16) throws {
        try self.helper.wait { future in
            nabto_client_tcp_tunnel_open(self.tunnel, future, service, localPort)
        }
    }

    /**
     * Open this tunnel asynchronously.
     * @param service The service to connect to on the remote device (as defined in the device's
     * configuration), e.g. "http", "http-admin", "ssh", "rtsp".
     * @param localPort The local port to listen on. If 0 is specified, an ephemeral port is used,
     * it can be retrieved with `getLocalPort()` when the tunnel has been opened successfully.
     * @param closure Invoked when the tunnel is opened or an error occurs.
     */
    public func openAsync(service: String,
                          localPort: UInt16,
                          closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_tcp_tunnel_open(self.tunnel, future, service, localPort)
        }
    }

    /**
     * Get the local TCP port, useful when opening tunnel with 0 as local port.
     * @throws INVALID_STATE if the tunnel is not open.
     * @returns the local port the local TCP server is listening on
     */
    public func getLocalPort() throws -> UInt16 {
        var port: UInt16 = 0
        let status = nabto_client_tcp_tunnel_get_local_port(self.tunnel, &port)
        try Helper.throwIfNotOk(status)
        return port
    }

    /**
     * Close this tunnel. Blocks until the tunnel is closed.
     * @throws INVALID_STATE if the tunnel is not open.
     */
    public func close() throws {
        try self.helper.wait { future in
            nabto_client_tcp_tunnel_close(self.tunnel, future)
        }
    }

    /**
     * Close this tunnel asynchronously.
     */
    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_tcp_tunnel_close(self.tunnel, future)
        }
    }

}
