//
//  MendozaSandboxUITests.swift
//  MendozaSandboxUITests
//
//  Created by tomas on 07/07/2019.
//  Copyright © 2019 tomas. All rights reserved.
//

import XCTest

class MendozaSandboxUITests: XCTestCase {
    override func setUp() {
        XCUIApplication().launch()
    }

    // func testExample1() { XCTAssert(true) }
    func testExampleFail() { XCTAssert(false) }
}
