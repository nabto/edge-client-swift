//
// Created by Ulrik Gammelby on 19/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public typealias AsyncDataReceiver = (NabtoEdgeClientError, Data?) -> Void

public class Stream {

    private let connection: NativeConnectionWrapper
    private let client: NativeClientWrapper
    private let stream: OpaquePointer
    private let helper: Helper
    private let chunkSize: Int = 1024
    private var activeCallbacks: Set<CallbackWrapper> = Set<CallbackWrapper>()

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

    public func openAsync(streamPort: UInt32, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_stream_open(self.stream, future, streamPort)
        }
    }

    public func write(data: Data) throws {
        try self.helper.wait() { future in
            doWrite(data, future)
        }
    }

    public func writeAsync(data: Data, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            doWrite(data, future)
        }
    }

    private func doWrite(_ data: Data, _ future: OpaquePointer?) {
        data.withUnsafeBytes { p in
            let rawPtr = p.baseAddress!
            nabto_client_stream_write(self.stream, future, rawPtr, data.count)
        }
    }

    public func readSome() throws -> Data {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.chunkSize)
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
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer {
            buffer.deallocate()
        }
        var readSize: Int = 0
        try self.helper.wait() { future in
            nabto_client_stream_read_all(self.stream, future, buffer, length, &readSize)
        }
        return Data(bytes: buffer, count: readSize)
    }

    public func readSomeAsync(closure: @escaping AsyncDataReceiver) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.chunkSize)
        var readSize: Int = 0
        nabto_client_stream_read_some(self.stream, future, buffer, self.chunkSize, &readSize)
        let w = CallbackWrapper(client: self.client, connection: nil, future: future, cb: { ec in
            if (ec == .OK) {
                closure(ec, Data(bytes: buffer, count: readSize))
            } else {
                closure(ec, nil)
            }
            buffer.deallocate()
        })
        w.setCleanupClosure(cleanupClosure: {
            self.activeCallbacks.remove(w)
        })
        self.activeCallbacks.insert(w)
    }

    public func readAllAsync(length: Int, closure: @escaping AsyncDataReceiver) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        var readSize: Int = 0
        nabto_client_stream_read_all(self.stream, future, buffer, length, &readSize)
        let w = CallbackWrapper(client: self.client, connection: nil, future: future, cb: { ec in
            if (ec == .OK) {
                closure(ec, Data(bytes: buffer, count: readSize))
            } else {
                closure(ec, nil)
            }
            buffer.deallocate()
        })
        w.setCleanupClosure(cleanupClosure: {
            self.activeCallbacks.remove(w)
        })
        self.activeCallbacks.insert(w)
    }

    public func close() throws {
        try self.helper.wait() { future in
            nabto_client_stream_close(self.stream, future)
        }
    }

    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_stream_close(self.stream, future)
        }
    }

    public func abort() {
        nabto_client_stream_abort(self.stream)
    }


}
