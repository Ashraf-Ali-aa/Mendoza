//
//  Event.swift
//  Mendoza
//
//  Created by Tomas Camin on 22/01/2019.
//

import Foundation
import MendozaSharedLibrary

public struct Event: Codable {
    let kind: Kind
    let info: [String: String]
    let testCase: TestCase

    public init(kind: Kind, info: [String: String], testCase: TestCase = .defaultInit()) {
        self.kind = kind
        self.info = info
        self.testCase = testCase
    }

    public enum Kind: Int, Codable {
        case start, stop
        case startCompiling, stopCompiling
        case startTesting, stopTesting
        case testSuiteStarted, testSuiteFinished
        case testCaseStarted, testCaseFinished
        case testPassed, testFailed, testCrashed
        case error
    }
}

extension Event.Kind: CustomReflectable {
    public var customMirror: Mirror {
        let kind = """
        enum Kind: Int, Codable {
            case start, stop
            case startCompiling, stopCompiling
            case startTesting, stopTesting
            case testSuiteStarted, testSuiteFinished
            case testCaseStarted, testCaseFinished
            case testPassed, testFailed, testCrashed
            case error
        }

        """

        return Mirror(self, children: ["hack": kind])
    }
}

extension Event.Kind: DefaultInitializable {
    public static func defaultInit() -> Event.Kind {
        .start
    }
}

extension Event: DefaultInitializable {
    public static func defaultInit() -> Event {
        return Event(kind: Event.Kind.defaultInit(), info: [:], testCase: .defaultInit())
    }
}
