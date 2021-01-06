//
// Created by Ulrik Gammelby on 19/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

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

    internal init(nabtoClient: NativeClientWrapper, nabtoConnection: NativeConnectionWrapper) throws {
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
     * @param streamPort: The listening id/port to use for the stream. This is used to
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
     * @param streamPort: The listening id/port to use for the stream. This is used to
     * distinguish streams in the other end, like a port number.
     * @param closure: Invoked when the stream is opened or an error occurs.
     */
    public func openAsync(streamPort: UInt32, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_stream_open(self.stream, future, streamPort)
        }
    }

    /**
     * Write data on a stream. Blocks until all data is written.
     *
     * When the call returns, the data is only written to the stream, but not necessarily
     * acknowledged by the receiver. This is why it does not make sense to return a number of actual
     * bytes written in case of error since it says nothing about the number of acked bytes. To
     * ensure that written bytes have been acked, a successful call to `Stream.close()` is
     * necessary after last call to this `Stream.write()`.
     *
     * @param data the data to write
     */
    public func write(data: Data) throws {
        try self.helper.wait() { future in
            doWrite(data, future)
        }
    }

    /**
     * Write data on a stream asynchronously.
     *
     * When the closure is invoked with an indication of success, the data is only written to the
     * stream, but not necessarily acknowledged by the receiver. This is why it does not make sense
     * to return a number of actual bytes written in case of error since it says nothing about the
     * number of acked bytes. To ensure that written bytes have been acked, a successful call to
     * `Stream.close()` is necessary after last call to this `Stream.write()`.
     *
     *
     */
    public func writeAsync(data: Data, closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            doWrite(data, future)
        }
    }

    /**
     * Read some bytes from a stream. Blocks until at least 1 byte is read or the stream is
     * closed or end of file is reached.
     *
     * If end of file is reached or the stream is aborted an error is thrown.
     */
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

    /**
     * Read some bytes from a stream asynchronously.
     *
     * Closure is invoked when at least 1 byte is read or the stream is closed or end of file is
     * reached.
     */
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


    /**
     * Read exactly the specified amount of bytes. Blocks until all bytes read.
     *
     * If all bytes could not be read (EOF or an error occurs or stream is aborted), an error is
     * thrown.
     */
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

    /**
     * Read exactly the specified amount of bytes asynchronously.
     *
     * Closure is invoked with a success indication when all bytes are read. Or an error if all
     * bytes could not be read (EOF or an error occurs or stream is aborted).  thrown.
     */
    public func readAllAsync(length: Int, closure: @escaping AsyncDataReceiver) {
        let future: OpaquePointer = nabto_client_future_new(self.client.nativeClient)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
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

    /**
     * Close the write direction of the stream. Blocks until the close is complete.
     *
     * This will make the other end reach end of file when reading from a stream when all sent data
     * has been received and acknowledged. A call to close does not affect the read direction of
     * the stream.
     */
    public func close() throws {
        try self.helper.wait() { future in
            nabto_client_stream_close(self.stream, future)
        }
    }

    /**
     * Close the write direction of the stream asynchronously.
     *
     * This will make the other end reach end of file when reading from a stream when all sent data
     * has been received and acknowledged. A call to close does not affect the read direction of
     * the stream.
     */
    public func closeAsync(closure: @escaping AsyncStatusReceiver) {
        self.helper.invokeAsync(userClosure: closure, connection: nil) { future in
            nabto_client_stream_close(self.stream, future)
        }
    }

    /**
     * Abort a stream.
     *
     * All pending read operations are aborted. The write direction is also closed.
     */
    public func abort() {
        nabto_client_stream_abort(self.stream)
    }

    private func doWrite(_ data: Data, _ future: OpaquePointer?) {
        data.withUnsafeBytes { p in
            let rawPtr = p.baseAddress!
            nabto_client_stream_write(self.stream, future, rawPtr, data.count)
        }
    }


}
