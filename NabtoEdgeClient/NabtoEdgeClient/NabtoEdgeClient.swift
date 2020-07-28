//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation

public class NabtoEdgeClient: NSObject {
    public func versionString() -> String {
        let c: NabtoEdgeClientObjC = NabtoEdgeClientObjC()
        return c.objc_nabto_client_version()
    }
}
