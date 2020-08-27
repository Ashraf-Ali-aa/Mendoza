//
//  MacOsValidationOperation.swift
//  Mendoza
//
//  Created by Tomas Camin on 22/03/2019.
//

import Foundation

class DeviceValidationOperation: BaseOperation<Void> {
    private let configuration: Configuration
    private let device: Device

    private lazy var pool: ConnectionPool = {
        makeConnectionPool(sources: configuration.nodes)
    }()

    init(configuration: Configuration, device: Device) {
        self.configuration = configuration
        self.device = device
    }

    override func main() {
        guard !isCancelled else { return }

        do {
            didStart?()

            try pool.execute { executer, _ in
                let simulator = CommandLineProxy.Simulators(executer: executer, verbose: false)
                let foundDevices = try simulator.findSimultorsBy(name: self.device.name, osVersion: self.device.osVersion)

                guard !foundDevices.isEmpty else {
                    throw Error("Failed to find: \(self.device.name) ::: \(self.device.runtime)\n\nThese are the available simulators with runtime version\n\(try simulator.installedSimulators().compactMap({ "\($0.name) ::: \($0.device.runtime)" }).joined(separator: "\n"))")
                }
            }

            didEnd?(())
        } catch {
            didThrow?(error)
        }
    }

    override func cancel() {
        if isExecuting {
            pool.terminate()
        }
        super.cancel()
    }
}
