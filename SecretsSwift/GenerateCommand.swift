import Foundation
import SwiftCLI
import Yams

class GenerateCommand: Command {
  let name = "generate"

  @Key("-c", "--config", description: "Configuration file path")
  var config: String?

  func execute() throws {
    let config: String

    if let givenConfig = self.config {
      config = givenConfig
    } else {
      config = "SecretsConfig"
    }

    if let filepath = Bundle.main.path(forResource: config, ofType: "yml") {
      do {
        let contents = try String(contentsOfFile: filepath)
        let secrets = try Yams.load(yaml: contents) as? [String: Any]
        let values = secrets?["keys"] as? [String: String]
        let environmentValues = secrets?["environments"] as? [String]
        let output = secrets?["output"] as? String
        let generator = Generator(values: values ?? [:],
                                  environment: environmentValues ?? [],
                                  outputPath: output ?? "Secrets.swift")
        try generator.generate()
      } catch {
        stdout <<< "Error! File cannot be loaded..."
      }
    } else {
      stdout <<< "Error! Enter the path of the configuration file..."
    }
  }
}
