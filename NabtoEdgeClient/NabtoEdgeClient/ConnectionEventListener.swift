//
// Created by Ulrik Gammelby on 06/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

internal class ConnectionEventListener {
    private let connection: OpaquePointer
    private let client: OpaquePointer
    private let future: OpaquePointer
    private let listener: OpaquePointer
    private let helper: Helper

    // simple set<> is a mess due to massive swift protocol quirks and an "abstract" class is not possible as it is not possible
    // to override api methods - so a simple objc hashtable seems best (see https://stackoverflow.com/questions/29278624/pure-swift-set-with-protocol-objects)
    private var userCbs: NSHashTable<ConnectionEventsCallbackReceiver> = NSHashTable<ConnectionEventsCallbackReceiver>()
    private var event: NabtoClientConnectionEvent = -1

    init(plaincNabtoConnection: OpaquePointer, plaincNabtoClient: OpaquePointer) throws {
        self.connection = plaincNabtoConnection
        self.client = plaincNabtoClient
        self.helper = Helper(nabtoClient: self.client)
        self.future = nabto_client_future_new(self.client)
        self.listener = nabto_client_listener_new(self.client)

        let ec = nabto_client_connection_events_init_listener(self.connection, self.listener)
        try Helper.throwIfNotOk(ec)

        nabto_client_listener_connection_event(self.listener, self.future, &self.event)

        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<ConnectionEventListener>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiEventCallback(ec: ec)
        }, rawSelf)
    }

    private func apiEventCallback(ec: NabtoClientError) {
        let enumerator = self.userCbs.objectEnumerator()
        while let cb = enumerator.nextObject() {
            let mappedEvent: NabtoEdgeClientConnectionEvent = lastEdgeClientConnectionEvent()
            (cb as! ConnectionEventsCallbackReceiver).onEvent(event: mappedEvent)
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

    internal func addUserCb(_ cb: ConnectionEventsCallbackReceiver) {
        self.userCbs.add(cb)
    }

    internal func removeUserCb(_ cb: ConnectionEventsCallbackReceiver) {
        self.userCbs.remove(cb)
    }

    deinit {
        nabto_client_listener_free(self.listener)
        nabto_client_future_free(self.future)
    }
}