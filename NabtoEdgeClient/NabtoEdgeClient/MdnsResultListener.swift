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
    /*
     * The implementation is invoked when an mDNS result is ready
     * @param result The callback result.
     */
    func onResultReady(result: MdnsResult)
}

internal class MdnsResultListener {
    private let client: NativeClientWrapper
    private let future: OpaquePointer
    private let listener: OpaquePointer
    private let helper: Helper

    // see comment on set vs hashtable and protocol/delegate vs closure on similar property in
    // ConnectionEventListener class
    private var userCbs: NSHashTable<MdnsResultReceiver> = NSHashTable<MdnsResultReceiver>()

    private var result: OpaquePointer? = nil

    init(nabtoClient: NativeClientWrapper, subType: String) throws {
        self.client = nabtoClient
        self.helper = Helper(nabtoClient: self.client)
        self.future = nabto_client_future_new(self.client.nativeClient)
        self.listener = nabto_client_listener_new(self.client.nativeClient)

        let ec = nabto_client_mdns_resolver_init_listener(self.client.nativeClient, self.listener, subType)
        try Helper.throwIfNotOk(ec)

        nabto_client_listener_new_mdns_result(self.listener, self.future, &self.result)

        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        nabto_client_future_set_callback(self.future, { (future: OpaquePointer?, ec: NabtoClientError, data: Optional<UnsafeMutableRawPointer>) -> Void in
            let mySelf = Unmanaged<MdnsResultListener>.fromOpaque(data!).takeUnretainedValue()
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
            if let res = self.result {
                (cb as! MdnsResultReceiver).onResultReady(result: self.createFromResult(res))
            }
        }
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

    internal func addUserCb(_ cb: MdnsResultReceiver) {
        self.userCbs.add(cb)
    }

    internal func removeUserCb(_ cb: MdnsResultReceiver) {
        self.userCbs.remove(cb)
    }

}
