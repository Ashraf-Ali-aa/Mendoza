//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import XCTest

// extensions to the ParsableArguments protocol to facilitate XCTestExpectation support
public protocol TestableParsableArguments: ParsableArguments {
    var didValidateExpectation: XCTestExpectation { get }
}

public extension TestableParsableArguments {
    mutating func validate() throws {
        didValidateExpectation.fulfill()
    }
}

// extensions to the ParsableCommand protocol to facilitate XCTestExpectation support
public protocol TestableParsableCommand: ParsableCommand, TestableParsableArguments {
    var didRunExpectation: XCTestExpectation { get }
}

public extension TestableParsableCommand {
    func run() throws {
        didRunExpectation.fulfill()
    }
}

extension XCTestExpectation {
    public convenience init(singleExpectation description: String) {
        self.init(description: description)
        expectedFulfillmentCount = 1
        assertForOverFulfill = true
    }
}

public func AssertResultFailure<T, U: Error>(
    _ expression: @autoclosure () -> Result<T, U>,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    switch expression() {
    case .success:
        let msg = message()
        XCTFail(msg.isEmpty ? "Incorrectly succeeded" : msg, file: file, line: line)
    case .failure:
        break
    }
}

public func AssertErrorMessage<A>(_: A.Type, _ arguments: [String], _ errorMessage: String, file: StaticString = #file, line: UInt = #line) where A: ParsableArguments {
    do {
        _ = try A.parse(arguments)
        XCTFail("Parsing should have failed.", file: file, line: line)
    } catch {
        // We expect to hit this path, i.e. getting an error:
        XCTAssertEqual(A.message(for: error), errorMessage, file: file, line: line)
    }
}

public func AssertFullErrorMessage<A>(_: A.Type, _ arguments: [String], _ errorMessage: String, file: StaticString = #file, line: UInt = #line) where A: ParsableArguments {
    do {
        _ = try A.parse(arguments)
        XCTFail("Parsing should have failed.", file: file, line: line)
    } catch {
        // We expect to hit this path, i.e. getting an error:
        XCTAssertEqual(A.fullMessage(for: error), errorMessage, file: file, line: line)
    }
}

public func AssertParse<A>(_ type: A.Type, _ arguments: [String], file: StaticString = #file, line: UInt = #line, closure: (A) throws -> Void) where A: ParsableArguments {
    do {
        let parsed = try type.parse(arguments)
        try closure(parsed)
    } catch {
        let message = type.message(for: error)
        XCTFail(#"\#(message)" — \#(error)"#, file: file, line: line)
    }
}

public func AssertParseCommand<A: ParsableCommand>(_ rootCommand: ParsableCommand.Type, _: A.Type, _ arguments: [String], file: StaticString = #file, line: UInt = #line, closure: (A) throws -> Void) {
    do {
        let command = try rootCommand.parseAsRoot(arguments)
        guard let aCommand = command as? A else {
            XCTFail("Command is of unexpected type: \(command)", file: file, line: line)
            return
        }
        try closure(aCommand)
    } catch {
        let message = rootCommand.message(for: error)
        XCTFail(#"\#(message)" — \#(error)"#, file: file, line: line)
    }
}

public func AssertEqualStringsIgnoringTrailingWhitespace(_ string1: String, _ string2: String, file: StaticString = #file, line: UInt = #line) {
    let lines1 = string1.split(separator: "\n", omittingEmptySubsequences: false)
    let lines2 = string2.split(separator: "\n", omittingEmptySubsequences: false)

    XCTAssertEqual(lines1.count, lines2.count, "Strings have different numbers of lines.", file: file, line: line)
    for (line1, line2) in zip(lines1, lines2) {
        XCTAssertEqual(line1.trimmed(), line2.trimmed(), file: file, line: line)
    }
}

public func AssertHelp<T: ParsableArguments>(
    for _: T.Type, equals expected: String,
    file: StaticString = #file, line: UInt = #line
) {
    do {
        _ = try T.parse(["-h"])
        XCTFail()
    } catch {
        let helpString = T.fullMessage(for: error)
        AssertEqualStringsIgnoringTrailingWhitespace(
            helpString, expected, file: file, line: line
        )
    }
}

extension XCTest {
    public var debugURL: URL {
        let bundleURL = Bundle(for: type(of: self)).bundleURL
        return bundleURL.lastPathComponent.hasSuffix("xctest") ? bundleURL.deletingLastPathComponent() : bundleURL
    }

    public var mendozaExecutablePath: String {
        let commandName = "Mendoza"
        let commandURL = debugURL.appendingPathComponent(commandName)
        guard (try? commandURL.checkResourceIsReachable()) ?? false else {
            XCTFail("No executable at '\(commandURL.standardizedFileURL.path)'.")
            return ""
        }

        var executablePath: String

        if #available(macOS 10.13, *) {
            executablePath = commandURL.absoluteString
        } else {
            executablePath = commandURL.path
        }

        let path = executablePath.replacingOccurrences(of: "file://", with: "")

        #if DEBUG
            print("mendoza executable Path: \(path)")
        #endif

        return path
    }

    public func AssertExecuteCommand(
        command: String,
        expected: String? = nil,
        exitCode: ExitCode = .success,
        file: StaticString = #file, line: UInt = #line
    ) {
        let splitCommand = command.split(separator: " ")
        let arguments = splitCommand.dropFirst().map(String.init)

        let commandName = String(splitCommand.first!)
        let commandURL = debugURL.appendingPathComponent(commandName)

        guard (try? commandURL.checkResourceIsReachable()) ?? false else {
            XCTFail("No executable at '\(commandURL.standardizedFileURL.path)'.", file: file, line: line)
            return
        }

        let process = Process()
        if #available(macOS 10.13, *) {
            process.executableURL = commandURL
        } else {
            process.launchPath = commandURL.path
        }
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        let error = Pipe()
        process.standardError = error

        if #available(macOS 10.13, *) {
            guard (try? process.run()) != nil else {
                XCTFail("Couldn't run command process.", file: file, line: line)
                return
            }
        } else {
            process.launch()
        }
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let outputActual = String(data: outputData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let errorActual = String(data: errorData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        print(outputActual)
        print(errorActual)

        if let expected = expected {
            AssertEqualStringsIgnoringTrailingWhitespace(expected, errorActual + outputActual, file: file, line: line)
        }

        XCTAssertEqual(process.terminationStatus, exitCode.rawValue, file: file, line: line)
    }

    @discardableResult
    func shell(_ command: String) -> ShellResult {
        let process = Process()

        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        let outputHandler = pipe.fileHandleForReading
        outputHandler.waitForDataInBackgroundAndNotify()

        var output = ""
        var dataObserver: NSObjectProtocol!
        let notificationCenter = NotificationCenter.default
        let dataNotificationName = NSNotification.Name.NSFileHandleDataAvailable

        dataObserver = notificationCenter.addObserver(forName: dataNotificationName, object: outputHandler, queue: nil) { _ in
            let data = outputHandler.availableData

            guard !data.isEmpty else {
                return notificationCenter.removeObserver(dataObserver as Any)
            }

            if let line = String(data: data, encoding: .utf8) {
                print(line)
                output = output + line + "\n"
            }

            outputHandler.waitForDataInBackgroundAndNotify()
        }

        process.launch()
        process.waitUntilExit()

        return ShellResult(output: output, status: process.terminationStatus)
    }
}

public struct ShellResult {
    let output: String
    let status: Int32
}

extension XCTest {
    @discardableResult
    func mendoza(command: String) -> ShellResult {
        let mendozaCommand = command.components(separatedBy: .whitespaces).dropFirst().joined(separator: " ")
        let terminalCommand = "\(mendozaExecutablePath) \(mendozaCommand)"

        return shell(terminalCommand)
    }

    @discardableResult
    func mendozaTest(
        config: String,
        deviceName: String,
        deviceRuntime: String,
        testForStability: Int = 0,
        retryCount: Int = 0,
        includedFiles _: String? = nil,
        excludedFiles _: String? = nil,
        includeTests: String? = nil,
        excludeTests: String? = nil,
        timeout _: Int = 120,
        pluginData: String? = nil,
        debug: Bool = false,
        customLocation: String? = nil
    ) -> ShellResult {
        var terminalCommand = "mendoza test \(config) "

        terminalCommand.append(contentsOf: argumentFormat(argName: "device_name", argValue: deviceName))
        terminalCommand.append(contentsOf: argumentFormat(argName: "device_runtime", argValue: deviceRuntime))

        if testForStability != 0 {
            terminalCommand.append(contentsOf: argumentFormat(argName: "test_for_stability", argNumber: testForStability))
        }

        if retryCount != 0 {
            terminalCommand.append(contentsOf: argumentFormat(argName: "failure_retry", argNumber: retryCount))
        }

        if let includeTests = includeTests {
            terminalCommand.append(contentsOf: argumentFormat(argName: "include_tests", argValue: includeTests))
        }

        if let excludeTests = excludeTests {
            terminalCommand.append(contentsOf: argumentFormat(argName: "exclude_tests", argValue: excludeTests))
        }

        if debug {
            terminalCommand.append(contentsOf: " --plugin_debug")
        }

        if let pluginData = pluginData {
            terminalCommand.append(contentsOf: argumentFormat(argName: "plugin_data", argValue: pluginData))
        }

        terminalCommand.append(contentsOf: argumentFormat(argName: "directory", argValue: customLocation ?? sandboxLocation))

        print("Running Command:")
        print(terminalCommand)

        return mendoza(command: terminalCommand)
    }

    fileprivate func argumentFormat(argName: String, argNumber: Int) -> String {
        return "--\(argName)=\(argNumber) "
    }

    fileprivate func argumentFormat(argName: String, argValue: String) -> String {
        return "--\(argName)=\"\(argValue)\" "
    }

    var sandboxLocation: String {
        return URL(fileURLWithPath: #file).pathComponents.prefix(while: { $0 != "Tests" }).joined(separator: "/").dropFirst() + "/SandboxProject/"
    }
}
