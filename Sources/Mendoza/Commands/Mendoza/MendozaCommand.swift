//
//  MendozaCommand.swift
//  Mendoza
//
//  Created by Tomas Camin on 20/09/2019.
//

import Foundation
import Bariloche

class MendozaCommand: Command {
    let name: String? = "mendoza"
    let usage: String? = "Mendoza internally used commands"
    let help: String? = "Internal"
    
    let commandName = Argument<[String]>(name: "command_name", kind: .variadic, optional: false)
    
    func run() -> Bool {
        guard let customCommand = commandName.value?.dropFirst().first else {
            return false
        }
        
        switch customCommand {
        case "simulator_locations":
            let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, CGWindowListOption.optionOnScreenOnly)

            guard let info = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[ String : Any]] else {
                return false
            }
            
            var result = [[String: Int]]()
            
            // On Catalina, unless you enable screen recording permissions,
            // you no longer get kCGWindowName access for security reasons
            for dict in info where dict["kCGWindowOwnerName"] as? String == "Simulator" {
                guard let windowBoundsInfo = dict["kCGWindowBounds"] as? [String: Int] else {
                    return false
                }
                
                result.append(windowBoundsInfo)
            }
            
            guard let data = try? JSONEncoder().encode(result) else { return false }
            print(String(decoding: data, as: UTF8.self))

            return true
        default:
            return false
        }
    }
}
