//
//  CommandLineSimulators.swift
//  Mendoza
//
//  Created by Tomas Camin on 31/01/2019.
//

import Foundation

extension CommandLineProxy {
    class Simulators {
        var settingsPath: String { return "\(executer.homePath)/Library/Preferences/com.apple.iphonesimulator.plist" }
        
        private var executer: Executer
        private let verbose: Bool
        
        init(executer: Executer, verbose: Bool) {
            self.executer = executer
            self.verbose = verbose
        }
        
        func wakeUp() throws {
            _ = try executer.execute("open -a \"$(xcode-select -p)/Applications/Simulator.app\"; sleep 5")
            let simulatorsBooting = try bootedSimulators()
            // Be nice to Simulator.app and wait for the default simulator to be booted. Random crashes and error happens doing otherwise
            for simulatorBooting in simulatorsBooting {
                try waitForBoot(simulator: simulatorBooting)
            }
        }
                
        func reset() throws {
            let commands = ["defaults read com.apple.iphonesimulator",
                            "killall -9 com.apple.CoreSimulator.CoreSimulatorService",
                            "pkill Simulator"]
            
            try commands.forEach { _ = try executer.execute("\($0) 2>/dev/null || true") }
        }
        
        func rewriteSettings() throws {
            try reset()
            
            let commands = ["rm '\(executer.homePath)/Library/Preferences/com.apple.iphonesimulator.plist' || true", // Delete iphone simulator settings to remove multiple `ScreenConfigurations` if present
                            "rm -rf '\(executer.homePath)/Library/Saved Application State/com.apple.iphonesimulator.savedState'",
                            "defaults read com.apple.iphonesimulator"]
            
            try commands.forEach { _ = try executer.execute("\($0) 2>/dev/null || true") }
            
            try wakeUp()
        }
                
        func shutdown(simulator: Simulator) throws {
            _ = try executer.execute("xcrun simctl shutdown \(simulator.id)")
        }
        
        func launchApp(identifier: String, on simulator: Simulator) throws {
            _ = try executer.execute("xcrun simctl launch \(simulator.id) \(identifier)")
        }
        
        func terminateApp(identifier: String, on simulator: Simulator) throws {
            _ = try executer.execute("xcrun simctl terminate \(simulator.id) \(identifier)")
        }
                
        func installRuntimeIfNeeded(_ runtime: String, nodeAddress: String, appleIdCredentials: Credentials?, administratorPassword: String?) throws {
            let isRuntimeInstalled: () throws -> Bool = { [unowned self] in
                let installedRuntimes = try self.executer.execute("xcrun simctl list runtimes")
                let escapedRuntime = runtime.replacingOccurrences(of: ".", with: "-")
                return installedRuntimes.contains("com.apple.CoreSimulator.SimRuntime.iOS-\(escapedRuntime)")
            }

            guard try !isRuntimeInstalled() else { return }
            
            guard let appleIdCredentials = appleIdCredentials
                , let password = administratorPassword else {
                throw Error("Could not install simulator runtime on node `\(nodeAddress)` because administrator credentials were not provided. Please install `\(runtime)` runtime manually")
            }

            print("🦶 Installing runtime \(runtime) on node \(executer.address)".bold)

            let keychain = Keychain(executer: executer)
            try keychain.unlock(password: password)

            executer.logger?.addBlackList(password)
            executer.logger?.addBlackList(appleIdCredentials.username)
            executer.logger?.addBlackList(appleIdCredentials.password)
            
            let cmds = ["export FASTLANE_USER=\(appleIdCredentials.username)",
                        "export FASTLANE_PASSWORD=\(appleIdCredentials.password)",
                        "rm -f ~/Library/Caches/XcodeInstall/com.apple.pkg.iPhoneSimulatorSDK\(runtime.replacingOccurrences(of: ".", with: "_"))*.dmg",
                        "xcversion update",
                        "echo '\(password)' | sudo -S xcversion simulators --install='iOS \(runtime)'",
                        "killall -9 com.apple.CoreSimulator.CoreSimulatorService"]
            
            let result = try executer.capture(cmds.joined(separator: "; "))
            guard result.status == 0 else {
                _ = try executer.execute("rm -rf \(executer.homePath)/Library/Caches/XcodeInstall/*.dmg")
                throw Error("Failed installing runtime!", logger: executer.logger)
            }
            guard !result.output.contains("specified Apple developer account credentials are incorrect") else {
                throw Error("The provided Apple developer account credentials are incorrect. Please run `\(ConfigurationRootCommand().name!) \(ConfigurationAuthententicationUpdateCommand().name!)` command", logger: executer.logger)
            }
            guard try isRuntimeInstalled() else {
                throw Error("Failed installing runtime, after install simulator runtime still not installed!", logger: executer.logger)
            }
        }

        /// This method instantiates a Simulator given a name.
        ///
        /// - Note: The simulator is created if necessary
        ///
        /// - Parameters:
        ///   - name: name of the device to create (e.g 'iPhone 6-1')
        ///   - device: the device instance to create
        /// - Returns: an instance of Simulator
        func makeSimulatorIfNeeded(name: String, device: Device) throws -> Simulator {            
            let simulatorsStatus = try executer.execute("$(xcode-select -p)/usr/bin/instruments -s devices")
            
            let statusRegex = try NSRegularExpression(pattern: #"(.*)\s\((\d+\.\d+(\.\d+)?)\)\s\[(.*)\]\s\(Simulator\)$"#)
            for simulatorStatus in simulatorsStatus.components(separatedBy: "\n") {
                let captureGroups = simulatorStatus.capturedGroups(regex: statusRegex)
                
                guard captureGroups.count == 4 else { continue }
                
                let simulatorName = captureGroups[0]
                let simulatorRuntime = captureGroups[1]
                let simulatorId = captureGroups[3]
                
                if simulatorName == name, simulatorRuntime == device.runtime {
                    return Simulator(id: simulatorId, name: name, device: device)
                }
            }
            
            #if DEBUG
                print("📱  Simulator \(name) not found, creating a new one")
            #endif

            // Simulator not found
            
            let devicesType = try executer.execute("xcrun simctl list devicetypes")
            
            let deviceRegex = try NSRegularExpression(pattern: #"\#(device.name) \(com.apple.CoreSimulator.SimDeviceType.(.*)\)$"#)
            for deviceType in devicesType.components(separatedBy: "\n") {
                let captureGroups = deviceType.capturedGroups(regex: deviceRegex)
                
                guard captureGroups.count == 1 else { continue }
                
                let deviceIdentifier = "com.apple.CoreSimulator.SimDeviceType." + captureGroups[0]
                let runtimeIdentifier = "com.apple.CoreSimulator.SimRuntime.iOS-" + device.runtime.replacingOccurrences(of: ".", with: "-")
                
                let simulatorIdentifier = try executer.execute("xcrun simctl create '\(name)' \(deviceIdentifier) \(runtimeIdentifier)")
                
                return Simulator(id: simulatorIdentifier, name: name, device: device)
            }

            throw Error("Failed making Simulator", logger: executer.logger)
        }
        
        func installedSimulators() throws -> [Simulator] {
            let simulatorsStatus = try executer.execute("$(xcode-select -p)/usr/bin/instruments -s devices")
            
            var simulators = [Simulator]()
            for status in simulatorsStatus.components(separatedBy: "\n") {
                let capture = try status.capturedGroups(withRegexString: #"(.*) \((.*)\) \[(.*)\] \(Simulator\)"#)
                
                guard capture.count == 3 else { continue }
                
                simulators.append(Simulator(id: capture[2], name: capture[0], device: Device(name: capture[0], runtime: capture[1])))
            }
            
            return simulators
        }
        
        func bootedSimulators() throws -> [Simulator] {
            let installed = try installedSimulators()
            
            var simulators = [Simulator]()
            let availableStatuses = try executer.execute("xcrun simctl list devices")
            for status in availableStatuses.components(separatedBy: "\n") {
                let capture = try status.capturedGroups(withRegexString: #"(.*) \((.*)\) \((.*)\)"#)
                
                guard capture.count == 3 else { continue }
                
                let simulatorStatus = capture[2]
                guard simulatorStatus == "Booted" else { continue }
                
                if let simulator = installed.first(where: { $0.id == capture[1] }) {
                    simulators.append(simulator)
                }
            }
            
            return simulators
        }
        
        func boot(simulator: Simulator, asynchronous: Bool = false) throws {
            let booted = try bootedSimulators()
            
            guard !booted.contains(simulator) else { return }
            
            if asynchronous {
                _ = try executer.execute("xcrun simctl boot '\(simulator.id)' &")
            } else {
                // https://gist.github.com/keith/33d3e28de4217f3baecde15357bfe5f6
                // boot and synchronously wait for device to boot
                _ = try executer.execute("xcrun simctl bootstatus '\(simulator.id)' -b")
            }
        }
        
        func waitForBoot(simulator: Simulator) throws {
            _ = try executer.execute("xcrun simctl bootstatus '\(simulator.id)'")
        }
        
        func fetchSimulatorSettings() throws -> Simulators.Settings {
            let loadSettings: () throws -> Simulators.Settings? = {
                let uniqueUrl = Path.temp.url.appendingPathComponent("\(UUID().uuidString).plist")
                try self.executer.download(remotePath: self.settingsPath, localUrl: uniqueUrl)
                
                guard let data = try? Data(contentsOf: uniqueUrl) else { return nil }
                
                return try? PropertyListDecoder().decode(Simulators.Settings.self, from: data)
            }
            
            var settings: Simulators.Settings?
            if try executer.fileExists(atPath: settingsPath) {
                settings = try? loadSettings()
            }
            
            if settings?.ScreenConfigurations?.keys.count == 0 {
                try CommandLineProxy.Simulators(executer: executer, verbose: verbose).rewriteSettings()
                settings = try? loadSettings()
                
                if settings?.ScreenConfigurations?.keys.count == 0 {
                    throw Error("Failed to reset simulator plist: ScreenConfigurations key missing", logger: executer.logger)
                }
            }
            
            guard let result = settings else {
                throw Error("Failed loading simulator plist", logger: executer.logger)
            }
            
            return result
        }
        
        func storeSimulatorSettings(_ settings: Simulators.Settings) throws {
            let data = try PropertyListEncoder().encode(settings)
            let uniqueUrl = Path.temp.url.appendingPathComponent("\(UUID().uuidString).plist")
            try data.write(to: uniqueUrl)
            
            _ = try executer.execute(#"rm "\#(settingsPath)""#)
            try executer.upload(localUrl: uniqueUrl, remotePath: settingsPath)
            
            // Force reload
            _ = try executer.execute("rm -rf '\(executer.homePath)/Library/Saved Application State/com.apple.iphonesimulator.savedState'")
            _ = try executer.execute("defaults read com.apple.iphonesimulator &>/dev/null")
        }
    }
}
