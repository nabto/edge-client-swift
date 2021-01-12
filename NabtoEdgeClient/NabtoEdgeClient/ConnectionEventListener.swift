//
// Created by Ulrik Gammelby on 06/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

internal class ConnectionEventListener {
    private let connection: NativeConnectionWrapper
    private let client: NativeClientWrapper
    private let future: OpaquePointer
    private let listener: OpaquePointer
    private let helper: Helper

    // Simple set<> is a mess due to massive swift protocol quirks and an "abstract" class is not
    // possible as it is not possible to override api methods - so a simple objc hashtable seems best
    // (see https://stackoverflow.com/questions/29278624/pure-swift-set-with-protocol-objects).
    // Protocol is used instead of closure callbacks as it is currently not possible to check for
    // equality of closures in swift, hence messing up removing a specific added receiver.
    private var userCbs: NSHashTable<ConnectionEventReceiver> = NSHashTable<ConnectionEventReceiver>()
    private var event: NabtoClientConnectionEvent = -1

    init(nabtoConnection: NativeConnectionWrapper, nabtoClient: NativeClientWrapper) throws {
        self.connection = nabtoConnection
        self.client = nabtoClient
        self.helper = Helper(nabtoClient: self.client)
        self.future = nabto_client_future_new(self.client.nativeClient)
        self.listener = nabto_client_listener_new(self.client.nativeClient)

        let ec = nabto_client_connection_events_init_listener(self.connection.nativeConnection, self.listener)
        try Helper.throwIfNotOk(ec)

        nabto_client_listener_connection_event(self.listener, self.future, &self.event)

        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<ConnectionEventListener>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiEventCallback(ec: ec)
        }, rawSelf)
    }

    deinit {
        nabto_client_listener_free(self.listener)
        nabto_client_future_free(self.future)
    }

    private func apiEventCallback(ec: NabtoClientError) {
        let enumerator = self.userCbs.objectEnumerator()
        while let cb = enumerator.nextObject() {
            let mappedEvent: NabtoEdgeClientConnectionEvent = lastEdgeClientConnectionEvent()
            (cb as! ConnectionEventReceiver).onEvent(event: mappedEvent)
        }
    }

    private func lastEdgeClientConnectionEvent() -> NabtoEdgeClientConnectionEvent {
        switch (self.event) {
        case NABTO_CLIENT_CONNECTION_EVENT_CONNECTED: return .CONNECTED
        case NABTO_CLIENT_CONNECTION_EVENT_CLOSED: return .CLOSED
        case NABTO_CLIENT_CONNECTION_EVENT_CHANNEL_CHANGED: return .CHANNEL_CHANGED
        default:
            return .UNEXPECTED_EVENT
        }
    }

    internal func addUserCb(_ cb: ConnectionEventReceiver) {
        self.userCbs.add(cb)
    }

    internal func removeUserCb(_ cb: ConnectionEventReceiver) {
        self.userCbs.remove(cb)
    }

}
