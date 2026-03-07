import SwiftCLI
import Regex

let generator = CLI(name: "sskeys")
generator.commands = [GenerateCommand()]
_ = generator.go()
