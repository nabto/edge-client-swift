//
//  ViewController.swift
//  NabtoEdgeClientHello
//
//  Created by Ulrik Gammelby on 27/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import UIKit
import NabtoEdgeClient

class ViewController: UIViewController {

    func invoke() throws {
        let client = NabtoEdgeClient.Client()
        client.enableNsLogLogging()
        try client.setLogLevel(level: "info")
        let connection = try client.createConnection()
        let privateKey = try client.createPrivateKey()
        try connection.setPrivateKey(key: privateKey)
        try connection.setProductId(id: "pr-fatqcwj9")
        try connection.setDeviceId(id: "de-avmqjaje")
        try connection.setServerKey(key: "sk-72c860c244a6014248e64d5273e3e0ec")
        try connection.connect()
        let coap = try connection.createCoapRequest(method: "GET", path: "/hello-world")
        let response = try coap.execute()
        DispatchQueue.main.async {
            self.spinner.stopAnimating()
            let body: String
            if (response.status == 205) {
                body = String(decoding: response.payload, as: UTF8.self)
            } else {
                body = "(no payload)"
            }
            self.label.text = "\(response.status): \(body)"
        }
    }
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBAction func buttonTapped(_ sender: Any) {
        self.spinner.startAnimating()
        DispatchQueue.global().async {
            do {
                try self.invoke()
            } catch {
                DispatchQueue.main.async {
                    self.label.text = "ERROR: \(error)"
                }
            }
        }
    }
    
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let str = "Client SDK Version: " + NabtoEdgeClient.Client.versionString()
        print(str)
        label.text = str
    }

}

