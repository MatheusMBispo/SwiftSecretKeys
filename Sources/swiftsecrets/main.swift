import SwiftCLI

let generator = CLI(name: "swiftsecrets")
generator.commands = [GenerateCommand()]
generator.go()
