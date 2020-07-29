//
//  NabtoEdgeClient.swift
//  NabtoEdgeClient
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeClientApi

// useful read - perhaps it is acceptably clean to interact directly with c api from swift:
// https://www.uraimo.com/2016/04/07/swift-and-c-everything-you-need-to-know

public enum NabtoEdgeClientError: Error {
    case ALLOCATION_ERROR
}

// typedef void (*NabtoClientLogCallback)(const NabtoClientLogMessage* message, void* data);
private typealias NativelLogCallBack = (Optional<UnsafePointer<NabtoClientLogMessage>>, Optional<UnsafeMutableRawPointer>) -> Void

public typealias LogCallBack = (NabtoEdgeClientLogMessage) -> Void

public struct NabtoEdgeClientLogMessage {
    var severity: Int
    var severityString: String
    var module: String?
    var file: String?
    var line: Int
    var message: String
}

public class NabtoEdgeClient: NSObject {

    private let plaincNabtoClient: OpaquePointer

    override public init() {
        self.plaincNabtoClient = nabto_client_new()
//        (39, 63) Cannot convert value of type '(NabtoClientLogMessage, UnsafePointer<Void>) -> ()' (aka '(NabtoClientLogMessage_, UnsafePointer<()>) -> ()') to expected argument type 'NabtoClientLogCallback?' (aka 'Optional<@convention(c) (Optional<UnsafePointer<NabtoClientLogMessage_>>, Optional<UnsafeMutableRawPointer>) -> ()>')
        // nabto_client_set_log_callback(self.plaincNabtoClient, defaultLogCallback, nil)
    }

    static func defaultLogCallback(m: Optional<UnsafePointer<NabtoClientLogMessage>>, data: Optional<UnsafeMutableRawPointer>) {
//        NSLog(String(cString: m!.message))
        // todo - handle other fields
    }

    deinit {
        nabto_client_free(self.plaincNabtoClient)
    }

    public func setLogLevel(level: String) {
        nabto_client_set_log_level(self.plaincNabtoClient, level)
    }

    public func setLogCallBack(cb: @escaping LogCallBack) {
    }

    public func createConnection() throws -> Connection {
        return try Connection(nabtoClient: plaincNabtoClient)
    }


    static public func versionString() -> String {
        return String(cString: nabto_client_version())
    }
}

public class Connection: NSObject {

    private var plaincNabtoConnection: OpaquePointer

    fileprivate init(nabtoClient: OpaquePointer) throws {
        plaincNabtoConnection = nabto_client_connection_new(nabtoClient)
        if (plaincNabtoConnection == nil) {
            throw NabtoEdgeClientError.ALLOCATION_ERROR
        }
    }

    deinit {
        nabto_client_connection_free(self.plaincNabtoConnection)
    }
}

