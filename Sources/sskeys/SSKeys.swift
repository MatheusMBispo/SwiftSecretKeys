import ArgumentParser

struct SSKeys: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sskeys",
        abstract: "Generate Swift files with obfuscated secrets.",
        subcommands: [GenerateCommand.self],
        defaultSubcommand: GenerateCommand.self
    )
}
