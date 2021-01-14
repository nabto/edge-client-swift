//
// Created by Ulrik Gammelby on 14/01/2021.
// Copyright (c) 2021 Nabto. All rights reserved.
//

import Foundation

/**
 * This class scans for local mDNS enabled devices.
 */
public class MdnsScanner {

    private let client: NativeClientWrapper
    private let listener: MdnsResultListener

    internal init(client: NativeClientWrapper, subType: String?) throws {
        self.client = client
        self.listener = MdnsResultListener(nabtoClient: client, subType: subType)
    }

    /**
     * Start the scan for local devices using mDNS.
     *
     * Add result listeners prior to invoking to ensure all results are retrieved.
     * @throws TBD
     */
    public func start() throws {
        try self.listener.start()
    }

    /**
     * Stop an active scan.
     */
    public func stop() {
        self.listener.stop()
    }

    /**
     * Add an mDNS result callback, invoked when an mDNS result is retrieved. Scan must be started separately (with start()).
     * @param cb An implementation of the MdnsResultReceiver protocol
     * @throw INVALID_STATE if callback could not be added
     */
    public func addMdnsResultReceiver(cb: MdnsResultReceiver) {
        self.listener.addUserCb(cb)
    }

    /**
     * Remove an mDNS result callback.
     * @param cb An implementation of the MdnsResultReceiver protocol
     */
    public func removeMdnsResultReceiver(cb: MdnsResultReceiver) {
        listener.removeUserCb(cb)
    }

}