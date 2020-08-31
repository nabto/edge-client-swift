//
// Created by Ulrik Gammelby on 26/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public class Tunnel {

    private let connection: NativeConnectionWrapper
    private let client: NativeClientWrapper
    private let tunnel: OpaquePointer
    private let helper: Helper

    init(nabtoClient: NativeClientWrapper, nabtoConnection: NativeConnectionWrapper) throws {
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

    public func open(service: String, localPort: UInt16) throws {
        try self.helper.wait() { future in
            nabto_client_tcp_tunnel_open(self.tunnel, future, service, localPort)
        }
    }

    public func getLocalPort() throws -> UInt16 {
        var port: UInt16 = 87
        let status = nabto_client_tcp_tunnel_get_local_port(self.tunnel, &port)
        try Helper.throwIfNotOk(status)
        return port
    }

    public func close() throws {
        try self.helper.wait() { future in
            nabto_client_tcp_tunnel_close(self.tunnel, future)
        }
    }

}