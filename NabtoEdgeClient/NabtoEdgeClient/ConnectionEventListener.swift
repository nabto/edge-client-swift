//
// Created by Ulrik Gammelby on 06/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

internal class ConnectionEventListener {
    private weak var connection: Connection?
    private weak var client: Client?
    private let future: OpaquePointer
    private let listener: OpaquePointer
    private let helper: Helper

    // simple set<> is a mess due to massive swift protocol quirks and an "abstract" class is not possible as it is not possible
    // to override api methods - so a simple objc hashtable seems best (see https://stackoverflow.com/questions/29278624/pure-swift-set-with-protocol-objects)
    private var userCbs: NSHashTable<ConnectionEventReceiver> = NSHashTable<ConnectionEventReceiver>()
    private var event: NabtoClientConnectionEvent = -1

    init(nabtoConnection: Connection, nabtoClient: Client) throws {
        self.connection = nabtoConnection
        self.client = nabtoClient
        self.helper = Helper(nabtoClient: nabtoClient)
        self.future = nabto_client_future_new(nabtoClient.nativeClient)
        self.listener = nabto_client_listener_new(nabtoClient.nativeClient)

        let ec = nabto_client_connection_events_init_listener(nabtoConnection.nativeConnection, self.listener)
        try Helper.throwIfNotOk(ec)

        nabto_client_listener_connection_event(self.listener, self.future, &self.event)

        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<ConnectionEventListener>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiEventCallback(ec: ec)
        }, rawSelf)
    }

    deinit {
        nabto_client_listener_stop(self.listener)
        nabto_client_listener_free(self.listener)
        nabto_client_future_free(self.future)
    }

    private func apiEventCallback(ec: NabtoClientError) {
        let enumerator = self.userCbs.objectEnumerator()
        while let cb = enumerator.nextObject() {
            print("apiEventCallback, ec=\(ec)")
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
