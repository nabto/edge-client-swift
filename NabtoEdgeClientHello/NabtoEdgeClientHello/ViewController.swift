//
//  ViewController.swift
//  NabtoEdgeClientHello
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeClient

final class BonjourResolver: NSObject, NetServiceDelegate {
    typealias CompletionHandler = (Result<(String, Int), Error>) -> Void
    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }

    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }

    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        assert(self.service == nil)
        assert(self.completionHandler == nil)
        assert(self.selfRetain == nil)
    }

    private var service: NetService? = nil
    private var completionHandler: (CompletionHandler)? = nil
    private var selfRetain: BonjourResolver? = nil

    private func start() {
        precondition(Thread.isMainThread)
        guard let service = self.service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in `stop(with:)`.
        selfRetain = self
    }

    func stop() {
        self.stop(with: .failure(CocoaError(.userCancelled)))
    }

    private func stop(with result: Result<(String, Int), Error>) {
        precondition(Thread.isMainThread)
        self.service?.delegate = nil
        self.service?.stop()
        self.service = nil
        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(result)

        selfRetain = nil
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        
        var rin = sockaddr_in()
        var rlen = socklen_t(MemoryLayout.size(ofValue: rin))
        var buffer = [CChar](repeating: 0, count: 128)

        let len = withUnsafeMutablePointer(to: &rin) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(sock, &buffer, buffer.count, 0, $0, &rlen)
            }
        }
        
        let ip = sender.addresses
        print(" *** ip: \(ip)")
        let port = sender.port
        self.stop(with: .success((hostName, port)))
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
                .flatMap { NetService.ErrorCode.init(rawValue: $0) }
                ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        self.stop(with: .failure(error))
    }
}

class ViewController: UIViewController, MdnsResultReceiver {
    func onResultReady(result: MdnsResult) {
        print("*** got mdns result: \(result)")
        DispatchQueue.main.async {
            self.label.text = result.description
        }
    }

    @IBAction func handleButtonTap(_ sender: Any) {
        let client = NabtoEdgeClient.Client()
        let scanner = client.createMdnsScanner()
        scanner.addMdnsResultReceiver(self)
        try! scanner.start()

        let service = NetService(domain: "local", type: "_nabto._udp.", name: "pr-cc9i4y7r-de-3cqgxbdm")

        print("will resolve, service: \(service)")
        BonjourResolver.resolve(service: service) { result in
            switch result {
            case .success(let hostName):
                print("did resolve, host: \(hostName)")
            case .failure(let error):
                print("did not resolve, error: \(error)")
            }
        }
        RunLoop.current.run()
        
                
    }
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let client = NabtoEdgeClient.Client()
        let connection = try! client.createConnection()
        label.text = "Version: " + NabtoEdgeClient.Client.versionString()

    }


}

