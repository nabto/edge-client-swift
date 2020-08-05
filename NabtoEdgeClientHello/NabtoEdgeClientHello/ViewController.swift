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

    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let client: NabtoEdgeClient = NabtoEdgeClient()
        let connection = try! client.createConnection()
        let options = try! connection.getOptions()
       // label.text = "Version: " + NabtoEdgeClient.versionString() + "\nOptions: [\(options)]"
        label.text = "Options: [\(options)]"
    }


}

