//
// Created by Ulrik Gammelby on 25/09/2021.
// Copyright (c) 2021 Nabto. All rights reserved.
//

import Foundation

@_implementationOnly import NabtoEdgeClientApi

class CallbackWrapper {

    // Nabto SDK level callback managed through this future
    let future: OpaquePointer

    // swift callback
    var cb: AsyncStatusReceiver?

    // keep this CallbackWrapper instance alive until the Nabto SDK level callback finishes
    var keepMeAlive: CallbackWrapper?

    // owner is kept alive for the duration of the Nabto SDK level callback
    let owner: Any

    // for connection specific error message (if available)
    let connectionForErrorMessage: NativeConnectionWrapper?

    // tmp debug
    let desc: String

    init(debugDescription: String, future: OpaquePointer, owner: Any, connectionForErrorMessage: NativeConnectionWrapper?=nil) {
        self.desc = debugDescription
        self.future = future
        self.owner = owner
        self.connectionForErrorMessage = connectionForErrorMessage
    }

    deinit {
        print("*** cb wrapper deinit end, thread: \(Thread.current)")
    }

    public func registerCallback(_ cb: @escaping AsyncStatusReceiver) throws {
        self.cb = cb
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        self.keepMeAlive = self
        let status = NABTO_CLIENT_EC_STOPPED
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<CallbackWrapper>.fromOpaque(data!).takeUnretainedValue()
            let wrapperError = Helper.mapToSwiftError(ec: ec, connection: mySelf.connectionForErrorMessage)
            mySelf.invokeUserCallback(wrapperError)
            mySelf.keepMeAlive = nil
        }, rawSelf)
//        if (status == NABTO_CLIENT_EC_STOPPED) {
//            self.keepMeAlive = nil
//            nabto_client_future_free(self.future)
//            throw NabtoEdgeClientError.STOPPED
//        }
    }

    func invokeUserCallback(_ wrapperError: NabtoEdgeClientError) {
        self.cb?(wrapperError)
        nabto_client_future_free(self.future)
    }


}