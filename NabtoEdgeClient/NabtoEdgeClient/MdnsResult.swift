//
// Created by Ulrik Gammelby on 1/12/21.
// Copyright (c) 2021 Nabto. All rights reserved.
//

import Foundation

/**
 * The result of an mDNS discovery request.
 */
public class MdnsResult : NSObject {

    /**
     * Actions emitted by device to manipulate the mDNS service cache in the client. Applies to the service identified
     * by serviceInstanceName in the result.
     */
    @objc public enum Action: Int {
        case ADD
        case UPDATE
        case REMOVE
        case UNEXPECTED_ACTION
    }

    /**
     * The service instance name. Can be considered a globally unique primary key for the announced
     * service and used for maintaining a service cache in the client, identifying each entry. The
     * provided action in the result specifies how the cache should be updated for this service.
     */
    public let serviceInstanceName: String

    /**
     * The action indicating how this result should be used for updating the client's service cache.
     */
    public let action: Action

    /**
     * Device id, nil if not set in the received result.
     */
    public let deviceId: String!

    /**
     * Product id, nil if not set in received result.
     */
    public let productId: String!

    /**
     * A map of txt records from received result.
     */
    public let txtItems: [String:String]

    init(serviceInstanceName: String, action: Action, deviceId: String?, productId: String?, txtItems: [String: String]?) {
        self.serviceInstanceName = serviceInstanceName
        self.action = action
        self.deviceId = deviceId
        self.productId = productId
        self.txtItems = txtItems ?? [:]
    }

    public override var description: String {
        "MdnsResult(serviceInstanceName: \(serviceInstanceName), action: \(action), deviceId: \(deviceId ?? "(nil)"), productId: \(productId ?? "(nil)"), txtItems: \(txtItems))"
    }
}
