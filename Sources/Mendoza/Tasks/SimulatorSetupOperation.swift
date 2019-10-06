//
//  SimulatorSetupOperation.swift
//  Mendoza
//
//  Created by Tomas Camin on 17/01/2019.
//

import Foundation

private struct ScreenResolution: Decodable { let width: Int; let height: Int }

class SimulatorSetupOperation: BaseOperation<[(simulator: Simulator, node: Node)]> {
    private var simulators = [(simulator: Simulator, node: Node)]()
    
    private let syncQueue = DispatchQueue(label: String(describing: SimulatorSetupOperation.self))
    private let configuration: Configuration
    private let nodes: [Node]
    private let device: Device
    private let verbose: Bool
    private lazy var pool: ConnectionPool = {
        return makeConnectionPool(sources: nodes)
    }()
    
    init(configuration: Configuration, nodes: [Node], device: Device, verbose: Bool) {
        self.nodes = nodes
        self.configuration = configuration
        self.device = device
        self.verbose = verbose
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        do {
            didStart?()
            
            let appleIdCredentials = configuration.appleIdCredentials()
            
            try pool.execute { (executer, source) in
                let node = source.node
                
                let proxy = CommandLineProxy.Simulators(executer: executer, verbose: self.verbose)
                
                try proxy.installRuntimeIfNeeded(self.device.runtime, nodeAddress: node.address, appleIdCredentials: appleIdCredentials, administratorPassword: node.administratorPassword ?? nil)
                
                let concurrentTestRunners = try self.physicalCPUs(executer: executer, node: node)
                let simulatorNames = (1...concurrentTestRunners).map { "\(self.device.name)-\($0)" }
                                
                let nodeSimulators = try simulatorNames.compactMap { try proxy.makeSimulatorIfNeeded(name: $0, device: self.device) }
                
                if try self.simulatorsReady(executer: executer, simulators: nodeSimulators) == false {
                    try? proxy.rewriteSettings()
                    nodeSimulators.forEach { try? proxy.boot(simulator: $0, asynchronous: true) }
                    nodeSimulators.forEach { try? proxy.waitForBoot(simulator: $0) }
                    
                    try self.updateSimulatorsArrangement(executer: executer, simulators: nodeSimulators)
                    try proxy.reset()
                }
                
                let simulatorProxy = CommandLineProxy.Simulators(executer: executer, verbose: self.verbose)
                let bootedSimulators = try simulatorProxy.bootedSimulators()
                for simulator in bootedSimulators {
                    try simulatorProxy.terminateApp(identifier: self.configuration.buildBundleIdentifier, on: simulator)
                    try simulatorProxy.terminateApp(identifier: self.configuration.testBundleIdentifier, on: simulator)
                }
                
                let unusedSimulators = bootedSimulators.filter { !nodeSimulators.contains($0) }
                for unusedSimulator in unusedSimulators {
                    try simulatorProxy.shutdown(simulator: unusedSimulator)
                }

                self.syncQueue.sync { [unowned self] in
                    self.simulators += nodeSimulators.map { (simulator: $0, node: source.node) }
                }
            }
            
            didEnd?(simulators)
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
    
    private func physicalCPUs(executer: Executer, node: Node) throws -> Int {
        guard let concurrentTestRunners = Int(try executer.execute("sysctl -n hw.physicalcpu")) else {
            throw Error("Failed getting concurrent simulators", logger: executer.logger)
        }

        return concurrentTestRunners
    }
    
    private func simulatorsReady(executer: Executer, simulators: [Simulator]) throws -> Bool {
        let rawLocations = try executer.execute(#"mendoza mendoza simulator_locations"#)
        
        let simulatorLocations = try JSONDecoder().decode([SimulatorWindowLocation].self, from: Data(rawLocations.utf8))
        
        guard simulators.count == simulatorLocations.count else {
            return false
        }
                
        let windowMenuBarHeight = 22
        let height = (simulatorLocations.first?.Height ?? 0)
        let y = simulatorLocations.first?.Y ?? -1
        let allHeigthsEqual = simulatorLocations.allSatisfy { $0.Height == height }
        let allYEqual = simulatorLocations.allSatisfy { $0.Y == y }
        let xLocations = simulatorLocations.map { $0.X }.sorted()
        
        let xLocations1 = xLocations.dropFirst()
        let xLocations2 = xLocations.dropLast()
        let deltaLocation = zip(xLocations1, xLocations2).map { $0.0 - $0.1 }
        let allDoNotOverlap = deltaLocation.allSatisfy { $0 >= height - windowMenuBarHeight }

        return false
        return allHeigthsEqual && allYEqual && allDoNotOverlap
    }
    
    /// This method arranges the simulators so that the do not overlap. For simplicity they're arranged on a single row
    ///
    /// Resolutions in points
    /// - iPhone
    ///      iPhone Xs Max: 414 x 896
    ///      iPhone Xʀ: 414 x 896
    ///      iPhone X/Xs: 375 x 812
    ///      iPhone+: 414 x 736
    ///      iPhone [6-8]: 375 x 667
    ///      iPhone 5: 320 x 568
    /// - iPad
    ///      iPad: 768 x 1024
    ///      iPad 10.5': 1112 x 834
    ///      iPad 12.9': 1024 x 1366
    ///
    /// - Note: On Mac (0,0) is the lower left corner
    ///
    /// - Parameters:
    ///   - param1: simulators to arrange
    private func updateSimulatorsArrangement(executer: Executer, simulators: [Simulator]) throws {
        _ = try? executer.execute("pkill -HUP Simulator")
        
        let simulatorProxy = CommandLineProxy.Simulators(executer: executer, verbose: verbose)
        
        let settings = try simulatorProxy.fetchSimulatorSettings()
        guard let screenConfiguration = settings.ScreenConfigurations
            , let screenIdentifier = Array(screenConfiguration.keys).last else {
            fatalError("💣 Failed to get screenIdentifier from simulator plist")
        }
        
        settings.CurrentDeviceUDID = nil
        
        settings.AllowFullscreenMode = false
        settings.PasteboardAutomaticSync = false
        settings.ShowChrome = false
        settings.ConnectHardwareKeyboard = false
        settings.OptimizeRenderingForWindowScale = false
        
        if settings.DevicePreferences == nil {
            settings.DevicePreferences = .init()
        }

        let displayMargin = 80
        let maxSimulatorsPerRow = 4
        let scaleFactor = try arrangedScaleFactor(executer: executer,
                                                  device: simulators.first!.device,
                                                  displayMargin: displayMargin,
                                                  totalSimulators: simulators.count,
                                                  maxSimulatorsPerRow: maxSimulatorsPerRow)
                
        for (index, simulator) in simulators.enumerated() {
            let center = try arrangedSimulatorCenter(index: index,
                                                     executer: executer,
                                                     device: simulators.first!.device,
                                                     displayMargin: displayMargin,
                                                     totalSimulators: simulators.count,
                                                     maxSimulatorsPerRow: maxSimulatorsPerRow)
            
            let devicePreferences = settings.DevicePreferences?[simulator.id] ?? .init()
            devicePreferences.SimulatorExternalDisplay = nil
            devicePreferences.SimulatorWindowOrientation = "Portrait"
            devicePreferences.SimulatorWindowRotationAngle = 0
            settings.DevicePreferences?[simulator.id] = devicePreferences
            
            if settings.DevicePreferences?[simulator.id]?.SimulatorWindowGeometry == nil {
                settings.DevicePreferences?[simulator.id]?.SimulatorWindowGeometry = .init()
            }
            
            let windowGeometry = settings.DevicePreferences?[simulator.id]?.SimulatorWindowGeometry?[screenIdentifier] ?? .init()
            windowGeometry.WindowScale = Double(scaleFactor)
            windowGeometry.WindowCenter = center
            settings.DevicePreferences?[simulator.id]?.SimulatorWindowGeometry?[screenIdentifier] = windowGeometry
            
            executer.logger?.log(command: "Arranging simulator \(simulator.id) on \(executer.address) at location (\(center))")
            executer.logger?.log(output: "", statusCode: 0)
            
            #if DEBUG
                print("⚠️ Arranging simulator \(simulator.id) on \(executer.address) at location (\(center))".bold)
            #endif
        }
        
        try simulatorProxy.storeSimulatorSettings(settings)
    }
    
    private func arrangedSimulatorCenter(index: Int, executer: Executer, device: Device, displayMargin: Int, totalSimulators: Int, maxSimulatorsPerRow: Int) throws -> String {
        let row = index / maxSimulatorsPerRow
        
        let resolution = try screenResolution(executer: executer)
        
        let largestDimension = device.pointSize().height
        let availableDimension = (resolution.width - displayMargin * 2) / min(totalSimulators, maxSimulatorsPerRow)
        
        let scaleFactor = try arrangedScaleFactor(executer: executer,
                                                  device: device,
                                                  displayMargin: displayMargin,
                                                  totalSimulators: totalSimulators,
                                                  maxSimulatorsPerRow: maxSimulatorsPerRow)
        
        let x = displayMargin + availableDimension / 2 + index * availableDimension
        let y = displayMargin + Int(largestDimension * scaleFactor / 2) * (row + 1)
        
        return "{\(x), \(y)}"
    }
    
    private func arrangedScaleFactor(executer: Executer, device: Device, displayMargin: Int, totalSimulators: Int, maxSimulatorsPerRow: Int) throws -> CGFloat {
        let resolution = try screenResolution(executer: executer)
        
        let largestDimension = device.pointSize().height
        let availableDimension = (resolution.width - displayMargin * 2) / min(totalSimulators, maxSimulatorsPerRow)
        return CGFloat(availableDimension) / CGFloat(largestDimension)
    }
        
    private func screenResolution(executer: Executer) throws -> ScreenResolution {
        let rawResolution = try executer.execute(#"mendoza mendoza screen_point_size"#)
        return try JSONDecoder().decode(ScreenResolution.self, from: Data(rawResolution.utf8))
    }
}

private struct SimulatorWindowLocation: Decodable {
    var X: Int
    var Y: Int
    var Height: Int
    var Width: Int
}
