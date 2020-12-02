//
// Created by Ulrik Gammelby on 19/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

public typealias AsyncDataReceiver = (NabtoEdgeClientError, Data?) -> Void

/**
 * A Nabto Edge stream enables socket-like communication between client and device. The stream is
 * reliable and ensures data is received ordered and complete. If either of these conditions cannot be
 * met, the stream will be closed in such a way that it is detectable.
 *
 * Stream instances are created using `Connection.createStream()`.
 */
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

    /**
     * Open this stream towards the target device. Blocks until the stream is opened.
     *
     * @parameter streamPort: The listening id/port to use for the stream. This is used to
     * distinguish streams in the other end, like a port number.
     */
    public func open(streamPort: UInt32) throws {
        try self.helper.wait() { future in
            nabto_client_stream_open(self.stream, future, streamPort)
        }
    }

    /**
     * Open this stream asynchronously towards the target device.
     *
     * @parameter streamPort: The listening id/port to use for the stream. This is used to
     * distinguish streams in the other end, like a port number.
     * @parameter closure: Invoked when the stream is opened or an error occurs.
     */
    public func openAsync(streamPort: UInt32, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_stream_open(self.stream, future, streamPort)
        }
    }

    /**
     * Write data on a stream. Blocks until all data is written.
     *
     * When the call returns, the data is only written to the stream, but not neccessary
     * acknowledged by the receiver. This is why it does not make sense to return a number of actual
     * bytes written in case of error since it says nothing about the number of acked bytes. To
     * ensure that written bytes have been acked, a succesful call to `Stream.close()` is
     * neccessary after last call to this `Stream.write()`.
     */
    public func write(data: Data) throws {
        try self.helper.wait() { future in
            doWrite(data, future)
        }
    }

    /**
     * Write data on a stream asynchronously.
     *
     * When the closure is invoked with an , the data is only written to the stream, but not neccessary
     * acknowledged by the receiver. This is why it does not make sense to return a number of actual
     * bytes written in case of error since it says nothing about the number of acked bytes. To
     * ensure that written bytes have been acked, a succesful call to `Stream.close()` is
     * neccessary after last call to this `Stream.write()`.
     */
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
