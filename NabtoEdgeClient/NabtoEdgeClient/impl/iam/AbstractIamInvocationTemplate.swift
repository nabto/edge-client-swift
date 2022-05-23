//
// Created by Ulrik Gammelby on 04/04/2022.
//

import Foundation

internal protocol AbstractIamInvocationTemplate {
    associatedtype T
    func mapResponse(_ response: CoapResponse) throws -> T

    typealias SyncHook = () throws -> ()
    typealias AsyncHook = (@escaping AsyncStatusReceiver) -> ()

    func mapStatus(status: UInt16?) -> IamError
    var method: String { get }
    var path: String { get }
    var connection: Connection { get }
    var cbor: Data? { get }
    var hookBeforeCoap: SyncHook? { get }
    var asyncHookBeforeCoap: AsyncHook? { get }
}

extension AbstractIamInvocationTemplate {

    func execute() throws -> T {
        do {
            try self.hookBeforeCoap?()
            let coap = try createCoapRequest(connection: connection)
            if let cbor = cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            let response = try coap.execute()
            let error = mapStatus(status: response.status)
            if (error == IamError.OK) {
                return try mapResponse(response)
            } else {
                throw error
            }
        } catch {
            try IamHelper.throwIamError(error)
        }
        throw IamError.FAILED // never here
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

    internal func executeAsyncWithData(_ closure: @escaping ((IamError, T?) -> ())) {
        if (self.asyncHookBeforeCoap != nil) {
            self.asyncHookBeforeCoap! { error in
                if (error == NabtoEdgeClientError.OK) {
                    self.executeAsyncWithDataImpl(closure)
                } else {
                    IamHelper.invokeIamErrorHandler(error, { error in
                        closure(error, nil)
                    })
                }
            }
        } else {
            self.executeAsyncWithDataImpl(closure)
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

    internal func executeAsyncWithDataImpl(_ closure: @escaping ((IamError, T?) -> ())) {
        do {
            let coap = try createCoapRequest(connection: connection)
            if let cbor = self.cbor {
                try coap.setRequestPayload(contentFormat: ContentFormat.APPLICATION_CBOR.rawValue, data: cbor)
            }
            coap.executeAsync { error, response in
                if (error == NabtoEdgeClientError.OK) {
                    if let response = response {
                        do {
                            let status = self.mapStatus(status: response.status)
                            let result: T?
                            if (status == IamError.OK) {
                                result = try mapResponse(response)
                            } else {
                                result = nil
                            }
                            closure(status, result)
                        } catch {
                            // mapping of status or response failed
                            IamHelper.invokeIamErrorHandler(error, { error in
                                closure(error, nil)
                            })
                        }
                    } else {
                        // ok, but no response - unlikely
                        closure(IamError.INVALID_RESPONSE(error: "status ok with no response from \(self.path)"), nil)
                    }
                } else {
                    // lower level api error
                    IamHelper.invokeIamErrorHandler(error, { error in
                        closure(error, nil)
                    })
                }
            }
        } catch {
            // create coap request failed
            IamHelper.invokeIamErrorHandler(error, { error in
                closure(error, nil)
            })
        }
    }

    private func createCoapRequest(connection: Connection) throws -> CoapRequest {
        return try connection.createCoapRequest(method: self.method, path: self.path)
    }
}