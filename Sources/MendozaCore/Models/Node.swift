//
//  Node.swift
//  Mendoza
//
//  Created by Tomas Camin on 10/01/2019.
//

import Foundation
import KeychainAccess

public struct Node: Codable, Equatable, Hashable {
    public enum ConcurrentTestRunners: Codable, Hashable {
        case manual(count: UInt)
        case autodetect
    }

    public let name: String
    public let address: String
    public let authentication: SSHAuthentication?
    public let administratorPassword: String?? // Required to perform tasks such as simulator runtime installation (e.g. `xcversion simulators --install='iOS X.X'`)
    public let concurrentTestRunners: ConcurrentTestRunners
    public let ramDiskSizeMB: UInt?

    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.address == rhs.address
    }

    public init(
        name: String,
        address: String,
        authentication: SSHAuthentication?,
        administratorPassword: String??,
        concurrentTestRunners: ConcurrentTestRunners,
        ramDiskSizeMB: UInt?
    ) {
        self.name = name
        self.address = address
        self.authentication = authentication
        self.administratorPassword = administratorPassword
        self.concurrentTestRunners = concurrentTestRunners
        self.ramDiskSizeMB = ramDiskSizeMB
    }
}

// MARK: - CustomStringConvertible

extension Node: CustomStringConvertible {
    public var description: String {
        var ret = ["name: \(name)", "address: \(address)"]
        if let authentication = authentication {
            ret += ["authentication: \(authentication)"]
        }
        if administratorPassword != nil {
            ret += ["store password: yes"]
        }
        if let ramDiskSizeMB = ramDiskSizeMB {
            ret += ["ram disk size: \(String(ramDiskSizeMB))"]
        }
        return ret.joined(separator: "\n")
    }
}

// MARK: - Codable

extension Node {
    private struct Authentication: Codable {
        let ssh: SSHAuthentication
        let administratorPassword: String?
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case address
        case concurrentTestRunners
        case ramDiskSizeMB
        case storeAdministratorPassword
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        concurrentTestRunners = try container.decode(ConcurrentTestRunners.self, forKey: .concurrentTestRunners)
        ramDiskSizeMB = try container.decodeIfPresent(UInt.self, forKey: .ramDiskSizeMB)

        let keychain = KeychainAccess.Keychain(service: Environment.bundle)

        if let authenticationData = try keychain.getData("\(name)_authentication") {
            let keychainAuthentication = try JSONDecoder().decode(Authentication.self, from: authenticationData)
            authentication = keychainAuthentication.ssh

            if try container.decode(Bool.self, forKey: .storeAdministratorPassword) {
                administratorPassword = .some(keychainAuthentication.administratorPassword)
            } else {
                administratorPassword = .none
            }
        } else {
            authentication = nil

            if try container.decode(Bool.self, forKey: .storeAdministratorPassword) {
                administratorPassword = .some(nil)
            } else {
                administratorPassword = .none
            }
        }
    }

    public static func localhost() -> Node {
        return Node(name: "localhost", address: "localhost", authentication: .none, administratorPassword: nil, concurrentTestRunners: .autodetect, ramDiskSizeMB: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(concurrentTestRunners, forKey: .concurrentTestRunners)
        try container.encodeIfPresent(ramDiskSizeMB, forKey: .ramDiskSizeMB)

        if let authentication = authentication {
            let keychain = KeychainAccess.Keychain(service: Environment.bundle)
            let keychainAuthentication = Authentication(ssh: authentication, administratorPassword: administratorPassword ?? nil)
            try keychain.set(try JSONEncoder().encode(keychainAuthentication), key: "\(name)_authentication")
        }

        try container.encode(administratorPassword != nil, forKey: .storeAdministratorPassword)
    }
}

extension Node.ConcurrentTestRunners {
    private enum CodingKeys: String, CodingKey {
        case manualCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let count = try container.decodeIfPresent(UInt.self, forKey: .manualCount) {
            self = .manual(count: count)
        } else {
            self = .autodetect
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .manual(count):
            try container.encode(count, forKey: .manualCount)
        case .autodetect:
            break
        }
    }
}
