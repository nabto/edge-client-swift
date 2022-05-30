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
        try client.setLogLevel(level: "trace")
        let connection = try client.createConnection()
        let privateKey = try client.createPrivateKey()
        try connection.setPrivateKey(key: privateKey)
        try connection.setProductId(id: "pr-fatqcwj9")
        try connection.setDeviceId(id: "de-ijrdq47i")
        try connection.setServerKey(key: "sk-9c826d2ebb4343a789b280fe22b98305")
        try connection.setServerConnectToken(sct: "WzwjoTabnvux")
        try connection.connect()
        let details: NabtoEdgeClient.DeviceDetails = try NabtoEdgeClient.IamUtil.getDeviceDetails(connection: connection)
        DispatchQueue.main.async {
            self.spinner.stopAnimating()
            self.label.text = "Device SDK Version: \(details.NabtoVersion)"
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
        label.text = "Client SDK Version: " + NabtoEdgeClient.Client.versionString()
    }

}

