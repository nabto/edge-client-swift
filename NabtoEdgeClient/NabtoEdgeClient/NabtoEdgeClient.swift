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
    case OK
    case ABORTED
    case ALLOCATION_ERROR
    case EOF
    case FORBIDDEN
    case NOT_FOUND
    case INVALID_ARGUMENT
    case INVALID_STATE
    case NO_CHANNELS
    case NO_DATA
    case NOT_CONNECTED
    case OPERATION_IN_PROGRESS
    case TIMEOUT
    case UNEXPECTED_API_STATUS
}

public typealias LogCallBackReceiver = (NabtoEdgeClientLogMessage) -> Void
public typealias AsyncStatusReceiver = (NabtoEdgeClientError) -> Void

public struct NabtoEdgeClientLogMessage {
    var severity: Int
    var severityString: String
    var file: String
    var line: Int
    var message: String
}

// bad (aktuel) - client doer:
// app --X--> client (deinit, client_free))
// app -----> connection

// client holdes i live af connection:
// app --X--> client
// app -----> connection -----> client

// leak?
// app --X--> client
// app --X--> connection -----> client

// client holdes i live af connection:
// app -----> client
// app -----> connection -----> client

internal protocol NativeClientWrapper {
    var nativeClient: OpaquePointer { get }
}

public class NabtoEdgeClient: NSObject, NativeClientWrapper {

    internal let nativeClient: OpaquePointer
    private var userLogCallBack: LogCallBackReceiver?
    private var apiLogCallBackRegistered: Bool = false

    override public init() {
        self.nativeClient = nabto_client_new()
    }

    deinit {
        nabto_client_free(self.nativeClient)
    }

    static public func versionString() -> String {
        return String(cString: nabto_client_version())
    }

    public func createConnection() throws -> Connection {
        return try Connection(client: self)
    }

    public func enableNsLogLogging() {
        self.setLogCallBack(cb: nslogLogCallback)
    }

    public func setLogLevel(level: String) throws {
        let status: NabtoClientError = nabto_client_set_log_level(self.nativeClient, level)
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
        let status = nabto_client_create_private_key(self.nativeClient, &p)
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
        let res = nabto_client_set_log_callback(self.nativeClient, { (pmsg: Optional<UnsafePointer<NabtoClientLogMessage>>, data: Optional<UnsafeMutableRawPointer>) -> Void in
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
