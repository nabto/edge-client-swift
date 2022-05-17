//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal protocol AbstractIamInvocationProtocol {

    typealias SyncHookWithResult = (CoapResponse) throws -> ()
    typealias SyncHook = () throws -> ()
    typealias AsyncHook = (@escaping AsyncStatusReceiver) -> ()

    func mapStatus(status: UInt16?) -> IamError
    var method: String { get }
    var path: String { get }
    var connection: Connection { get }
    var cbor: Data? { get }
    var hookBeforeCoap: SyncHook? { get }
    var asyncHookBeforeCoap: AsyncHook? { get }
    var hookAfterCoap: SyncHookWithResult? { get }
}

extension AbstractIamInvocationProtocol {

    func execute() throws {
        do {
            try self.hookBeforeCoap?()
            let coap = try createCoapRequest(connection: connection)
            if let cbor = cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            let response = try coap.execute()
            let error = mapStatus(status: response.status)
            if (error == IamError.OK) {
                try self.hookAfterCoap?(response)
            } else {
                throw error
            }
        } catch {
            try IamHelper.throwIamError(error)
        }
    }

    internal func executeAsync(_ closure: @escaping AsyncIamResultReceiver) {
        if (self.asyncHookBeforeCoap != nil) {
            self.asyncHookBeforeCoap! { error in
                if (error == NabtoEdgeClientError.OK) {
                    self.executeAsyncImpl(closure)
                } else {
                    IamHelper.invokeIamErrorHandler(error, closure)
                }
            }
        } else {
            self.executeAsyncImpl(closure)
        }
    }

    internal func executeAsyncImpl(_ closure: @escaping AsyncIamResultReceiver) {
        do {
            let coap = try createCoapRequest(connection: connection)
            if let cbor = self.cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            coap.executeAsync { error, response in
                if (error != NabtoEdgeClientError.OK) {
                    IamHelper.invokeIamErrorHandler(error, closure)
                } else {
                    closure(self.mapStatus(status: response?.status))
                }
            }
        } catch {
            IamHelper.invokeIamErrorHandler(error, closure)
        }
    }

    private func createCoapRequest(connection: Connection) throws -> CoapRequest {
        return try connection.createCoapRequest(method: self.method, path: self.path)
    }
}