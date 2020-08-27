//
//  TestTool.swift
//  MendozaTests
//
//  Created by Ashraf Ali on 30/06/2020.
//

import XCTest
@testable import MendozaCore
import MendozaSharedLibrary

class TestTool: XCTestCase {
    func testExample() throws {
        setEnvironment(variable: "MENDOZA_DEBUG", value: "true", overwrite: true)
        
        let includePatternField = sandboxLocation
        let excludePatternField = ""

        let includeTestField = "help"
        let excludeTestField = ""

        let device = Device(name: "iPad Pro (12.9-inch) (4th generation)", osVersion: "13.5")
        let timeout = 120
        let filePatterns = FilePatterns(commaSeparatedIncludePattern: includePatternField, commaSeparatedExcludePattern: excludePatternField)
        let testFilters = TestFilters(commaSeparatedIncludePattern: includeTestField, commaSeparatedExcludePattern: excludeTestField)
        let testForStabilityCount = 0
        let failingTestsRetryCount = 0

        let sut = try Test(
            configurationFile: "mendoza.json",
            device: device,
            runHeadless: false,
            filePatterns: filePatterns,
            testFilters: testFilters,
            testTimeoutSeconds: timeout,
            testForStabilityCount: testForStabilityCount,
            failingTestsRetryCount: failingTestsRetryCount,
            dispatchOnLocalHost: false,
            pluginData: nil,
            debugPlugins: false,
            verbose: true,
            directory: sandboxLocation
        )

        try sut.run()
    }
}
