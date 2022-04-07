//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal protocol PairAbstractProtocol {

    typealias SyncHook = () throws -> ()
    typealias AsyncHook = (@escaping AsyncStatusReceiver) -> Void

    func mapStatus(status: UInt16?) -> PairingError
    var method: String { get }
    var path: String { get }
    var connection: Connection { get }
    var cbor: Data? { get }
    var hookBeforeCoap: SyncHook? { get }
    var asyncHookBeforeCoap: AsyncHook? { get }
}

extension PairAbstractProtocol {

    func execute() throws {
        do {
            try self.hookBeforeCoap?()
            let coap = try createCoapRequest(connection: connection)
            if let cbor = cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            let response = try coap.execute()
            let error = mapStatus(status: response.status)
            if (error != PairingError.OK) {
                throw error
            }
        } catch {
            try PairingHelper.throwPairingError(error)
        }
    }

    internal func executeAsync(_ closure: @escaping AsyncPairingResultReceiver) {
        if (self.asyncHookBeforeCoap != nil) {
            self.asyncHookBeforeCoap! { error in
                if (error == NabtoEdgeClientError.OK) {
                    self.executeAsyncImpl(closure)
                } else {
                    PairingHelper.invokePairingErrorHandler(error, closure)
                }
            }
        } else {
            self.executeAsyncImpl(closure)
        }
    }

    internal func executeAsyncImpl(_ closure: @escaping AsyncPairingResultReceiver) {
        do {
            let coap = try createCoapRequest(connection: connection)
            if let cbor = cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            coap.executeAsync { error, response in
                if (error != NabtoEdgeClientError.OK) {
                    PairingHelper.invokePairingErrorHandler(error, closure)
                } else {
                    closure(self.mapStatus(status: response?.status))
                }
            }
        } catch {
            PairingHelper.invokePairingErrorHandler(error, closure)
        }
    }

    private func createCoapRequest(connection: Connection) throws -> CoapRequest {
        return try connection.createCoapRequest(method: self.method, path: self.path)
    }
}