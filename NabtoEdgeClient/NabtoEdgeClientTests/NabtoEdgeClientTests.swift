//
//  NabtoEdgeClientTests.swift
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

import XCTest
import NabtoEdgeClient

class NabtoEdgeClientTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testVersionString() throws {
        let sut = NabtoEdgeClient()
        XCTAssertEqual("5.", sut.versionString().prefix(2))
    }
}
