import Foundation
let data =  #"{"xcodeBuildCommand":["$(xcode-select -p)\/usr\/bin\/xcodebuild","build-for-testing","-project SandboxProject\/MendozaSandbox.xcodeproj","-scheme 'MendozaSandboxUITests'","-configuration Debug","-derivedDataPath '\/tmp\/mendoza\/build'","-sdk 'iphonesimulator'","-UseNewBuildSystem=YES","-enableCodeCoverage YES","COMPILER_INDEX_STORE_ENABLE=NO","ONLY_ACTIVE_ARCH=YES","VALID_ARCHS='x86_64'","GCC_OPTIMIZATION_LEVEL='s' SWIFT_OPTIMIZATION_LEVEL='-Osize'"]}"#


 struct XcodeBuildCommand: Codable {
     var arguments: Array<String>
 }

 struct PreCompilationInput: Codable {
     var xcodeBuildCommand: Array<String>
 }

struct PreCompilationPlugin {
    func handle(_ input: PreCompilationInput, pluginData: String?) -> XcodeBuildCommand {
        var commands = input.xcodeBuildCommand

        let xcconfig = "-xcconfig debug.xcconfig"


        commands.append(xcconfig)

        commands.append(contentsOf: [
            "PRODUCT_BUNDLE_IDENTIFIER='com.subito.MendozaSandboxUITests'",
            "CODE_SIGN_IDENTITY='iPhone Distribution'",
            "PROVISIONING_PROFILE_SPECIFIER='test.com.* Wildcard'",
            "DEVELOPMENT_TEAM='KSJ235TNYL'",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) AUTOMATION'"
        ])

        return XcodeBuildCommand(arguments: commands)
    }
}

let pluginData = ""

let inputData = data.data(using: .utf8)!
let input = try! JSONDecoder().decode(PreCompilationInput.self, from: inputData)

let result = PreCompilationPlugin().handle(input, pluginData: pluginData)

let outputData = try! JSONEncoder().encode(result)
//print("\n# plugin-result")
//print(String(data: outputData, encoding: .utf8)!)

