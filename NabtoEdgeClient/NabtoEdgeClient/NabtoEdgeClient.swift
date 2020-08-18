//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

// useful read: https://www.uraimo.com/2016/04/07/swift-and-c-everything-you-need-to-know

public enum NabtoEdgeClientError: Error {
    case ALLOCATION_ERROR
    case INVALID_ARGUMENT
    case INVALID_STATE
    case NO_DATA
    case NO_CHANNELS
    case NOT_CONNECTED
    case UNEXPECTED_API_STATUS
}

public typealias LogCallBackReceiver = (NabtoEdgeClientLogMessage) -> Void

public struct NabtoEdgeClientLogMessage {
    var severity: Int
    var severityString: String
    var file: String
    var line: Int
    var message: String
}

public class NabtoEdgeClient: NSObject {

    private let plaincNabtoClient: OpaquePointer
    private var userLogCallBack: LogCallBackReceiver?
    private var apiLogCallBackRegistered: Bool = false

    override public init() {
        self.plaincNabtoClient = nabto_client_new()
    }

    deinit {
        nabto_client_free(self.plaincNabtoClient)
    }

    static public func versionString() -> String {
        return String(cString: nabto_client_version())
    }

    public func createConnection() throws -> Connection {
        return try Connection(nabtoClient: plaincNabtoClient)
    }

    public func enableNsLogLogging() {
        self.setLogCallBack(cb: nslogLogCallback)
    }

    public func setLogLevel(level: String) throws {
        let status: NabtoClientError = nabto_client_set_log_level(self.plaincNabtoClient, level)
        if (status != NABTO_CLIENT_EC_OK) {
            throw NabtoEdgeClientError.INVALID_ARGUMENT
        }
    }

    public func setLogCallBack(cb: @escaping LogCallBackReceiver) {
        self.userLogCallBack = cb
        if (!self.apiLogCallBackRegistered) {
            self.registerApiLogCallback()
        } else {
            // nabto_client_set_log_callback seems to always succeed
        }
    }

    public func createPrivateKey() throws -> String {
        var p: UnsafeMutablePointer<Int8>? = nil
        let status = nabto_client_create_private_key(self.plaincNabtoClient, &p)
        return try Helper.handleStringResult(status: status, cstring: p)
    }

    private func nslogLogCallback(msg: NabtoEdgeClientLogMessage) {
        NSLog("Nabto log: \(msg.file):\(msg.line) [\(msg.severity)/\(msg.severityString)]: \(msg.message)")
    }

    private func apiLogCallback(msg: NabtoClientLogMessage) {
        guard let cb = self.userLogCallBack else {
            return
        }
        let userMsg = NabtoEdgeClientLogMessage(
                severity: Int(msg.severity.rawValue),
                severityString: String(cString: msg.severityString),
                file: (String(cString: msg.file) as NSString).lastPathComponent,
                line: Int(msg.line),
                message: String(cString: msg.message))
        cb(userMsg)
    }

    private func registerApiLogCallback() {
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        let res = nabto_client_set_log_callback(self.plaincNabtoClient, { (pmsg: Optional<UnsafePointer<NabtoClientLogMessage>>, data: Optional<UnsafeMutableRawPointer>) -> Void in
            if (pmsg == nil || data == nil) {
                return
            }
            let msg: NabtoClientLogMessage = pmsg!.pointee
            let mySelf = Unmanaged<NabtoEdgeClient>.fromOpaque(data!).takeUnretainedValue()
            mySelf.apiLogCallback(msg: msg)
        }, rawSelf)
        if (res == NABTO_CLIENT_EC_OK) {
            self.apiLogCallBackRegistered = true
        }
    }

}
