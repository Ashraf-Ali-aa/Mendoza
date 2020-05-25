//
//  TestCase.swift
//  Mendoza
//
//  Created by Tomas Camin on 20/01/2019.
//

import Foundation

struct TestCase: Codable, Hashable {
    let name: String
    let suite: String
    let tags: [String]
    let testCaseIDs: [String]

    var testIdentifier: String { return "\(suite)/\(name)" }

    init(name: String, suite: String, tags: [String] = [], testCaseIDs: [String] = []) {
        self.name = name.replacingOccurrences(of: "()", with: "")
        self.suite = suite
        self.tags = tags
        self.testCaseIDs = testCaseIDs
    }

    static func == (lhs: TestCase, rhs: TestCase) -> Bool {
        return lhs.name == rhs.name
    }
}

extension TestCase: DefaultInitializable {
    static func defaultInit() -> TestCase {
        return TestCase(name: "", suite: "")
    }
}

extension TestCase: CustomStringConvertible {
    var description: String { suite + " " + name }
}
