import SwiftCLI
import Regex

let generator = CLI(name: "swiftsecrets")
generator.commands = [GenerateCommand()]
generator.go()
