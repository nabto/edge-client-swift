//
// Created by Ulrik Gammelby on 06/08/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

import Foundation
@_implementationOnly import NabtoEdgeClientApi

/**
 * This protocol specifies a callback function to receive mDNS results
 */
@objc public protocol MdnsResultReceiver {
    /**
     * The implementation is invoked when an mDNS result is ready
     *
     * @param result The callback result.
     */
    func onResultReady(result: MdnsResult)
}

/**
 * This class scans for local mDNS enabled devices. It is created with Client.createMdnsScanner().
 */
public class MdnsScanner: NSObject {
    private let client: NativeClientWrapper
    private let future: OpaquePointer
    private var listener: OpaquePointer?
    private let helper: Helper
    private let subType: String?
    private var result: OpaquePointer? = nil
    private let serialQueue = DispatchQueue(label: "MdnsResultListener.serialQueue")
    private var selfReference: MdnsScanner?

    // see comment on set vs hashtable and protocol/delegate vs closure on similar property in
    // ConnectionEventListener class
    private var userCbs: NSHashTable<MdnsResultReceiver> = NSHashTable<MdnsResultReceiver>()

    internal init(client: NativeClientWrapper, subType: String?) {
        self.client = client
        self.helper = Helper(client: self.client)
        self.future = nabto_client_future_new(self.client.nativeClient)
        self.subType = subType
        super.init()
    }

    deinit {
        if (self.isStarted()) {
            self.stop()
        }
        nabto_client_future_free(self.future)
    }

    /**
     * Start the scan for local devices using mDNS.
     *
     * Add result listeners prior to invoking to ensure all results are retrieved.
     * @throws INVALID_STATE if the scan could not be started, e.g. if the client is being stopped
     */
    public func start() throws {
        try self.serialQueue.sync {
            guard self.listener == nil else {
                return
            }
            self.listener = nabto_client_listener_new(self.client.nativeClient)
            var ec = nabto_client_mdns_resolver_init_listener(
                    self.client.nativeClient, self.listener, self.subType ?? "" /* nil causes crash (NABTO-2359) */)
            try Helper.throwIfNotOk(ec)
            // prevent ARC reclaim until we get a close event
            self.selfReference = self
            ec = self.armListener()
            try Helper.throwIfNotOk(ec)
        }
    }

    /**
     * Stop an active scan.
     */
    public func stop() {
        self.serialQueue.sync {
            guard self.listener != nil else {
                return
            }
            nabto_client_listener_stop(self.listener)
            nabto_client_listener_free(self.listener)
            self.listener = nil
        }
    }

    /**
     * Query if a scan is active.
     */
    public func isStarted() -> Bool {
        self.serialQueue.sync {
            return self.listener != nil
        }
    }

    /**
     * Add an mDNS result callback, invoked when an mDNS result is retrieved. Scan must be started separately (with start()).
     * @param cb An implementation of the MdnsResultReceiver protocol
     * @throws INVALID_STATE if callback could not be added
     */
    public func addMdnsResultReceiver(_ cb: MdnsResultReceiver) {
        self.userCbs.add(cb)
    }

    /**
     * Remove an mDNS result callback.
     * @param cb An implementation of the MdnsResultReceiver protocol
     */
    public func removeMdnsResultReceiver(_ cb: MdnsResultReceiver) {
        self.userCbs.remove(cb)
    }

    private func apiEventCallback(ec: NabtoClientError) {
        guard (ec == NABTO_CLIENT_EC_OK) else {
            // allow ARC to reclaim us
            self.selfReference = nil
            return
        }
        let enumerator = self.userCbs.objectEnumerator()
        while let cb = enumerator.nextObject() {
            if let res = self.result {
                (cb as! MdnsResultReceiver).onResultReady(result: self.createFromResult(res))
            }
        }

        let stayAlive = self.isStarted() && self.armListener() == NABTO_CLIENT_EC_OK
        if (!stayAlive) {
            self.selfReference = nil
        }
    }

    private func armListener() -> NabtoClientError {
        nabto_client_listener_new_mdns_result(self.listener, self.future, &self.result)
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        return nabto_client_future_set_callback2(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<MdnsScanner>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiEventCallback(ec: ec)
        }, rawSelf)
    }

    private func createFromResult(_ res: OpaquePointer) -> MdnsResult {
        let name = String(cString: nabto_client_mdns_result_get_service_instance_name(res))
        let action = self.toSwiftAction(nabto_client_mdns_result_get_action(res))
        let deviceId: String? = self.toOptional(String(cString: nabto_client_mdns_result_get_device_id(res)))
        let productId: String? = self.toOptional(String(cString: nabto_client_mdns_result_get_product_id(res)))
        let txtItems = self.jsonToStringMap(String(cString: nabto_client_mdns_result_get_txt_items(res)))
        return MdnsResult(
                serviceInstanceName: name,
                action: action,
                deviceId: deviceId,
                productId: productId,
                txtItems: txtItems)
    }

    private func toOptional(_ str: String) -> String? {
        return str.isEmpty ? nil : str
    }

    private func jsonToStringMap(_ str: String) -> [String:String] {
        guard !str.isEmpty else {
            return [:]
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(str.utf8), options: []) as? [String: String] {
                return json
            } else {
                return [:]
            }
        } catch {
            return [:]
        }
    }

    private func toSwiftAction(_ apiAction: NabtoClientMdnsAction) -> MdnsResult.Action {
        switch (apiAction) {
        case NABTO_CLIENT_MDNS_ACTION_ADD: return .ADD
        case NABTO_CLIENT_MDNS_ACTION_REMOVE: return .REMOVE
        case NABTO_CLIENT_MDNS_ACTION_UPDATE: return .UPDATE
        default:
            return .UNEXPECTED_ACTION
        }
    }


}
