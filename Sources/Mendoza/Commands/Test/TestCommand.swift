//
//  CommandTest.swift
//  Mendoza
//
//  Created by Tomas Camin on 13/12/2018.
//

import Bariloche
import Foundation
import MendozaCore

class TestCommand: Command {
    let name: String? = "test"
    let usage: String? = "Dispatch UI tests as specified in the `configuration_file`"
    let help: String? = "Dispatch UI tests"

    let debugPluginsFlag = Flag(short: nil, long: "plugin_debug", help: "Dump plugin invocation commands")
    let dispatchOnLocalHostFlag = Flag(short: "l", long: "use_localhost", help: "Use localhost to execute tests")
    let verboseFlag = Flag(short: nil, long: "verbose", help: "Dump debug messages")
    let nonHeadlessSimulatorsFlag = Flag(short: nil, long: "non_headless_simulators", help: "Run simulators in non headless mode")

    let configurationPathField = Argument<String>(name: "configuration_file", kind: .positional, optional: false, help: "Mendoza's configuration file path", autocomplete: .files("json"))
    let includePatternField = Argument<String>(name: "files", kind: .named(short: "f", long: "include_files"), optional: true, help: "Specify from which files UI tests should be extracted. Accepts wildcards and comma separated. e.g SBTA*.swift,SBTF*.swift. Default: '*.swift'", autocomplete: .files("swift"))
    let excludePatternField = Argument<String>(name: "files", kind: .named(short: "x", long: "exclude_files"), optional: true, help: "Specify which files should be skipped when extracting UI tests. Accepts wildcards and comma separated. e.g SBTA*.swift,SBTF*.swift. Default: ''", autocomplete: .files("swift"))
    let deviceNameField = Argument<String>(name: "name", kind: .named(short: "d", long: "device_name"), optional: true, help: "Device name to use to run tests. e.g. 'iPhone 8'")
    let deviceRuntimeField = Argument<String>(name: "version", kind: .named(short: "v", long: "device_runtime"), optional: true, help: "Device runtime to use to run tests. e.g. '13.0'")

    let includeTestField = Argument<String>(name: "test", kind: .named(short: "in", long: "include_tests"), optional: true, help: "Specify from which UI tests should be included based on tags. Accepts comma separated. e.g smokeTest,regression")
    let excludeTestField = Argument<String>(name: "test", kind: .named(short: "ex", long: "exclude_tests"), optional: true, help: "Specify from which UI tests should be excluded based on tags. Accepts comma separated. e.g smokeTest,regression*")

    let timeoutField = Argument<Int>(name: "seconds", kind: .named(short: nil, long: "timeout"), optional: true, help: "Maximum allowed idle time (in seconds) in test standard output before dispatch process is automatically terminated. Default 120 seconds")
    let pluginCustomField = Argument<String>(name: "data", kind: .named(short: nil, long: "plugin_data"), optional: true, help: "A custom string that can be used to inject data to plugins")
    let testForStabilityRetryCountField = Argument<Int>(name: "count", kind: .named(short: "ts", long: "test_for_stability"), optional: true, help: "Number of times a tests should be repeated to determin if test is stable")
    let failingTestsRetryCountField = Argument<Int>(name: "count", kind: .named(short: "r", long: "failure_retry"), optional: true, help: "Number of times a failing tests should be repeated")

    let directoryPath = Argument<String>(name: "path", kind: .named(short: nil, long: "directory"), optional: true, help: "directory path for project, useful for internal debugging")

    func run() -> Bool {
        do {
            let device: Device
            if let deviceName = deviceNameField.value, let deviceRuntime = deviceRuntimeField.value {
                device = Device(name: deviceName, osVersion: deviceRuntime)
            } else {
                device = Device.defaultInit()
            }

            let timeout = timeoutField.value ?? 120
            let filePatterns = FilePatterns(commaSeparatedIncludePattern: includePatternField.value, commaSeparatedExcludePattern: excludePatternField.value)
            let testFilters = TestFilters(commaSeparatedIncludePattern: includeTestField.value, commaSeparatedExcludePattern: excludeTestField.value)
            let testForStabilityCount = testForStabilityRetryCountField.value ?? 0
            let failingTestsRetryCount = failingTestsRetryCountField.value ?? 0

            let test = try Test(
                configurationFile: configurationPathField.value ?? Environment.defaultConfigurationFilename,
                device: device,
                runHeadless: !nonHeadlessSimulatorsFlag.value,
                filePatterns: filePatterns,
                testFilters: testFilters,
                testTimeoutSeconds: timeout,
                testForStabilityCount: testForStabilityCount,
                failingTestsRetryCount: failingTestsRetryCount,
                dispatchOnLocalHost: dispatchOnLocalHostFlag.value,
                pluginData: pluginCustomField.value,
                debugPlugins: debugPluginsFlag.value,
                verbose: verboseFlag.value,
                directory: directoryPath.value
            )

            test.didFail = { [weak self] in self?.handleError($0) }
            try test.run()
        } catch {
            handleError(error)
        }

        return true
    }

    private func handleError(_ error: Swift.Error) {
        print(error.localizedDescription)

        if !(error is Error) {
            print("\n\(String(describing: error))")
        }

        exit(-1)
    }
}
