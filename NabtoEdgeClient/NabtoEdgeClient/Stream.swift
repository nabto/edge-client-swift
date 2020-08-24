//
// Created by Ulrik Gammelby on 19/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi


public class Stream {

    private let connection: NativeConnectionWrapper
    private let client: NativeClientWrapper
    private let stream: OpaquePointer
    private let helper: Helper
    private let chunkSize: Int = 1024

    init(nabtoClient: NativeClientWrapper, nabtoConnection: NativeConnectionWrapper) throws {
        self.client = nabtoClient
        self.connection = nabtoConnection
        self.helper = Helper(nabtoClient: self.client)
        let p = nabto_client_stream_new(self.connection.nativeConnection)
        if (p != nil) {
            self.stream = p!
        } else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
    }

    deinit {
        nabto_client_stream_free(self.stream)
    }

    public func open(streamPort: UInt32) throws {
        try self.helper.wait() { future in
            nabto_client_stream_open(self.stream, future, streamPort)
        }
    }

    public func write(data: Data) throws {
        try self.helper.wait() { future in
            data.withUnsafeBytes { p in
                let rawPtr = p.baseAddress!
                nabto_client_stream_write(self.stream, future, rawPtr, data.count)
            }
        }
    }

    public func readSome() throws -> Data {
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.chunkSize)
        defer {
            buffer.deallocate()
        }
        var readSize: Int = 0
        try self.helper.wait() { future in
            nabto_client_stream_read_some(self.stream, future, buffer, self.chunkSize, &readSize)
        }
        return Data(bytes: buffer, count: readSize)
    }

    public func readAll(length: Int) throws -> Data {
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer {
            buffer.deallocate()
        }
        var readSize: Int = 0
        try self.helper.wait() { future in
            nabto_client_stream_read_all(self.stream, future, buffer, length, &readSize)
        }
        return Data(bytes: buffer, count: readSize)
    }

    public func close() throws {
        try self.helper.wait() { future in
            nabto_client_stream_close(self.stream, future)
        }
    }

}
