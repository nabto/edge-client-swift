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
    let connectionForErrorMessage: Connection?

    // tmp debug
    let desc: String

    init(debugDescription: String, future: OpaquePointer, owner: Any, connectionForErrorMessage: Connection?=nil) {
        self.desc = debugDescription
        self.future = future
        self.owner = owner
        self.connectionForErrorMessage = connectionForErrorMessage
        NSLog(" ***** [\(self.desc)] callback wrapper init *****")
    }

    deinit {
        NSLog(" ***** [\(self.desc)] callback wrapper deinit *****")
    }

    public func registerCallback(_ cb: @escaping AsyncStatusReceiver) {
        self.cb = cb
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        self.keepMeAlive = self
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<CallbackWrapper>.fromOpaque(data!).takeUnretainedValue()
            NSLog(" ***** [\(mySelf.desc)] callback wrapper nabto callback (begin) *****")
            let wrapperError = Helper.mapToSwiftError(ec: ec, connection: mySelf.connectionForErrorMessage)
            mySelf.invokeUserCallback(wrapperError)
            NSLog(" ***** [\(mySelf.desc)] callback wrapper nabto callback nil'ing self to allow deinit *****")
            mySelf.keepMeAlive = nil
            NSLog(" ***** [\(mySelf.desc)] callback wrapper nabto callback (end) *****")
        }, rawSelf)
    }

    func invokeUserCallback(_ wrapperError: NabtoEdgeClientError) {
        self.cb?(wrapperError)
        nabto_client_future_free(self.future)
    }


}