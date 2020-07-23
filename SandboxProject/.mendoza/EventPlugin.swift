#!/usr/bin/swift

import Foundation

// enum Kind: Int, Codable {
//     case start, stop
//     case startCompiling, stopCompiling
//     case startTesting, stopTesting
//     case testSuiteStarted, testSuiteFinished
//     case testCaseStarted, testCaseFinished
//     case testPassed, testFailed, testCrashed
//     case error
// }
// 
// struct Event: Codable {
//     var kind: Kind
//     var info: Dictionary<String, String>
//     var testCase: TestCase
// }
// 
// struct Device: Codable {
//     var name: String
//     var osVersion: String
//     var runtime: String
// }
// 
// struct EventPluginInput: Codable {
//     var event: Event
//     var device: Device
// }
//
// struct TestCase: Codable {
//     var name: String
//     var suite: String
//     var tags: Array<String>
//     var testCaseIDs: Array<String>
// }

struct EventPlugin {
    func handle(_ input: EventPluginInput, pluginData: String?) {
        let event = input.event.kind
        let eventInfo = input.event.info
        let testCase = input.event.testCase

        switch event {
        case .start: break
        case .startCompiling: break
        case .stopCompiling: break
        case .startTesting: testStarted(eventInfo: eventInfo, testCase: testCase)
        case .testSuiteStarted: break
        case .testCaseStarted: testCaseStarted(eventInfo: eventInfo, testCase: testCase)
        case .testPassed: testCasePassed(eventInfo: eventInfo, testCase: testCase)
        case .testFailed: testCaseFailed(eventInfo: eventInfo, testCase: testCase)
        case .testCrashed: testCaseCrashed(eventInfo: eventInfo, testCase: testCase)
        case .testCaseFinished: break
        case .testSuiteFinished: break
        case .error: testError(eventInfo: eventInfo, testCase: testCase)
        case .stopTesting: testFinished(eventInfo: eventInfo, testCase: testCase)
        case .stop: break
        }
    }
}

extension EventPlugin {
    func testStarted(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Testing Started", data: eventInfo, testCase: testCase)
    }

    func testCaseStarted(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Test Case Started", data: eventInfo, testCase: testCase)
    }

    func testCasePassed(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Test Case Passed", data: eventInfo, testCase: testCase)
    }

    func testCaseFailed(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Test Case Failed", data: eventInfo, testCase: testCase)
    }

    func testCaseCrashed(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Test Case Crashed", data: eventInfo, testCase: testCase)
    }

    func testFinished(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Testing Finished", data: eventInfo, testCase: testCase)
    }

    func testError(eventInfo: [String: String], testCase: TestCase ) {
        logEvent(message: "Error", data: eventInfo, testCase: testCase)
    }
}

extension EventPlugin {
    func logEvent(message: String, data: [String: String], testCase: TestCase) {
        if (ProcessInfo.processInfo.environment["MENDOZA_DEBUG"] != nil) {
            print("\(message)\n\(data)\n\(testCase.testCaseIDs)\n\(testCase.tags)")
        }
    }
}

struct Network {
    func request(url: String, method: String, headers: [(key: String, value: String)]? = nil, requestData: Data? = nil) {
        // Prepare URL
        guard let requestUrl = URL(string: url) else {
            fatalError("Incorrect URL")
        }

        // Prepare URL Request Object
        var request = URLRequest(url: requestUrl)
        request.httpMethod = method

        // Set HTTP Request Body
        if let requestBody = requestData {
            request.httpBody = requestBody
        }

        if let headers = headers {
            headers.forEach {
                request.addValue($0.value, forHTTPHeaderField: $0.value)
            }
        }

        // Perform HTTP Request
        let task = URLSession.shared.dataTask(with: request) { data, _, error in

            // Check for Error
            if let error = error {
                print("Error took place \(error)")
                return
            }

            // Convert HTTP Response Data to a String
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response data string:\n \(dataString)")
            }
        }
        task.resume()
    }
}

extension URLSession {
    func performSynchronous(request: URLRequest) -> (data: Data?, response: URLResponse?, error: Error?) {
        let semaphore = DispatchSemaphore(value: 0)

        var data: Data?
        var response: URLResponse?
        var error: Error?

        let task = dataTask(with: request) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        return (data, response, error)
    }
}

// MARK: TM4J

// let testCycle = try? JSONDecoder().decode(TestCycle.self, from: jsonData)
struct TestCycle: Codable {
    let estimatedTime: Int?
    let updatedBy: String?
    let issueKey: String?
    let updatedOn: String?
    let createdOn: String?
    let issueCount: Int?
    let plannedEndDate: String?
    let executionTime: Int?
    let projectKey: String?
    let testCaseCount: Int?
    let folder: String?
    let plannedStartDate: String?
    let createdBy: String?
    let name: String?
    let items: [Item]?
    let key: String?
    let executionSummary: ExecutionSummary?
    let status: Status?
}

// MARK: - ExecutionSummary

struct ExecutionSummary: Codable {
    let notExecuted: Int?

    enum CodingKeys: String, CodingKey {
        case notExecuted
    }
}

// MARK: - Item

struct Item: Codable {
    let executedBy: String?
    let actualEndDate: String?
    let testCaseKey: String?
    let id: Int?
    let status: Status?
}

enum Status: String, Codable {
    case notExecuted = "Not Executed"
    case executed = "Executed"
}
