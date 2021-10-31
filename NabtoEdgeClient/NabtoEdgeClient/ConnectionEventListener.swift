//
// Created by Ulrik Gammelby on 06/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

internal class ConnectionEventListener {
    private weak var client: ClientImpl?
    private weak var connection: Connection?
    private let future: OpaquePointer
    private let listener: OpaquePointer
    private var keepSelfAlive: ConnectionEventListener?
    private var event: NabtoClientConnectionEvent = -1

    // simple set<> is a mess due to massive swift protocol quirks and an "abstract" class is not possible as it is not possible
    // to override api methods - so a simple objc hashtable seems best (see https://stackoverflow.com/questions/29278624/pure-swift-set-with-protocol-objects)
    private var userCbs: NSHashTable<ConnectionEventReceiver> = NSHashTable<ConnectionEventReceiver>()

    init(client: ClientImpl, connection: Connection) {
        self.client = client
        self.connection = connection
        self.future = nabto_client_future_new(client.nativeClient)
        self.listener = nabto_client_listener_new(client.nativeClient)
    }

    deinit {
        nabto_client_listener_free(self.listener)
        nabto_client_future_free(self.future)
    }

    private func start() throws {
        guard let c = self.connection else {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
        let ec = nabto_client_connection_events_init_listener(c.nativeConnection, self.listener)
        try Helper.throwIfNotOk(ec)
        // prevent ARC reclaim until we get a close event
        self.keepSelfAlive = self
        self.armListener()
    }

    private func apiEventCallback(ec: NabtoClientError) {
        if (ec == NABTO_CLIENT_EC_STOPPED) {
            // allow ARC to reclaim us
            self.keepSelfAlive = nil
            return
        }
        guard (ec == NABTO_CLIENT_EC_OK) else {
            return
        }
        let cbs = self.userCbs.copy() as! NSHashTable<ConnectionEventReceiver>
        let enumerator = cbs.objectEnumerator()
        while let cb = enumerator.nextObject() {
            let mappedEvent: NabtoEdgeClientConnectionEvent = lastEdgeClientConnectionEvent()
            (cb as! ConnectionEventReceiver).onEvent(event: mappedEvent)
        }
        self.armListener()
    }

    private func armListener() {
        nabto_client_listener_connection_event(self.listener, self.future, &self.event)
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback2(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<ConnectionEventListener>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiEventCallback(ec: ec)
        }, rawSelf)
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

    internal func addUserCb(_ cb: ConnectionEventReceiver) throws {
        self.userCbs.add(cb)
        try self.start()
    }

    internal func removeUserCb(_ cb: ConnectionEventReceiver) {
        self.userCbs.remove(cb)
        if (self.userCbs.count == 0) {
            self.stop()
        }
    }

    internal func hasUserCbs() -> Bool {
        return self.userCbs.count > 0
    }

    internal func stop() {
        nabto_client_listener_stop(self.listener)
    }

}
