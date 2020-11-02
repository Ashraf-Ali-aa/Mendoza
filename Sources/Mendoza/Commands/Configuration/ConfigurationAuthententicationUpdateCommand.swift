//
//  ConfigurationAuthententicationUpdateCommand.swift
//  Mendoza
//
//  Created by Tomas Camin on 30/01/2019.
//

import Bariloche
import Foundation

class ConfigurationAuthententicationUpdateCommand: Command {
    let name: String? = "authentication"
    let usage: String? = "Update authentication data required by configuration file"
    let help: String? = "Update authentication information"

    let configuration = Argument<URL>(name: "configuration_file", kind: .positional, optional: false, help: "Mendoza's configuration file path", autocomplete: .files("json"))

    let username = Argument<String>(name: "adminUser", kind: .named(short: nil, long: "adminUser"), optional: true, help: "machine user")
    let password = Argument<String>(name: "adminPassword", kind: .named(short: nil, long: "adminPassword"), optional: true, help: "machine password")
    let appleIDUsername = Argument<String>(name: "appleID", kind: .named(short: nil, long: "appleID"), optional: true, help: "Apple ID user")
    let appleIDPassword = Argument<String>(name: "appleIDPassword", kind: .named(short: nil, long: "appleIDPassword"), optional: true, help: "Apple ID password")
    

    func run() -> Bool {
        do {
            try ConfigurationAuthenticationUpdater(
                configurationUrl: configuration.value!,
                adminUsername: username.value,
                adminPassword: password.value,
                appleID: appleIDUsername.value,
                apppleIDPassword: appleIDPassword.value
            ).run() // swiftlint:disable:this force_unwrapping
        } catch {
            print(error.localizedDescription.red.bold)
            exit(-1)
        }

        return true
    }
}
