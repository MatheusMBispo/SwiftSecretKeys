import SwiftCLI

let generator = CLI(name: "secrets")
generator.commands = [GenerateCommand()]
generator.go()
