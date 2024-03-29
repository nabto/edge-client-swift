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
    var selfReference: CallbackWrapper?

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
    }

    public func registerCallback(_ cb: @escaping AsyncStatusReceiver) -> NabtoClientError {
        self.cb = cb
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        self.selfReference = self
        let status = nabto_client_future_set_callback2(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<CallbackWrapper>.fromOpaque(data!).takeUnretainedValue()
            let wrapperError = Helper.mapToSwiftError(ec: ec, connection: mySelf.connectionForErrorMessage)
            mySelf.invokeUserCallback(wrapperError)
            mySelf.selfReference = nil
        }, rawSelf)
        if (status != NABTO_CLIENT_EC_OK) {
            self.selfReference = nil
            nabto_client_future_free(self.future)
        }
        return status
    }

    func invokeUserCallback(_ wrapperError: NabtoEdgeClientError) {
        self.cb?(wrapperError)
        nabto_client_future_free(self.future)
    }


}
