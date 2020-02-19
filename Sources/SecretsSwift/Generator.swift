import Foundation
import Stencil

enum GeneratorError: Error {
    case invalidEnvironmentVariable
}

class Generator {
    let values: [String: String]
    let outputPath: String
    let environment: [String]

    init(values: [String: String], environment: [String], outputPath: String) {
        self.values = values
        self.outputPath = outputPath
        self.environment = environment
    }

    func chunked(array: [UInt8], into size: Int) -> [[UInt8]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0 ..< Swift.min($0 + size, array.count)])
        }
    }

    func encode(_ str: String, cipher: [UInt8]) -> [UInt8] {
        let data = str.data(using: .utf8)
        let encrypted = data!.enumerated().map { offset, element in
            element ^ cipher[offset % cipher.count]
        }
        return encrypted
    }

    struct Config {
        var name: String
        var value: [[UInt8]]
    }

    func generate() throws {
        let salt = randomText(32)
        let cipher = salt.data(using: .utf8)!.bytes
        let salt_chunks = chunked(array: cipher, into: 10)

        var configs = [Config]()
        for (key, value) in values {
            let encodedVar = encode(value, cipher: cipher)
            configs.append(Config(name: key, value: chunked(array: encodedVar, into: 10)))
        }

        var environments = [Config]()
        for value in environment {
            guard let environmentValue = ProcessInfo.processInfo.environment[value] else { throw GeneratorError.invalidEnvironmentVariable }
            let encodedVar = encode(environmentValue, cipher: cipher)
            environments.append(Config(name: value, value: chunked(array: encodedVar, into: 10)))
        }

        let loader = FileSystemLoader(bundle: [Bundle.main])
        let environment = Environment(loader: loader)
        let context: [String: Any] = [
            "salt_chunks": salt_chunks,
            "vars": configs,
            "environments": environments
        ]

        do {
            let rendered = try environment.renderTemplate(string: template, context: context)

            let dir = FileManager.default.currentDirectoryPath + "/" + outputPath
            let fileURL = URL(fileURLWithPath: dir)

            try rendered.write(to: fileURL, atomically: false, encoding: .utf8)
        }
        catch {
            print("The desired file could not be generated.")
        }
    }

    let template = """
    import Foundation

    enum Secrets {
     private static let salt: [UInt8] = [{% for salt_chunk in salt_chunks %}
          {% for salt in salt_chunk %}{{ salt }}, {% endfor %}{% endfor %}
     ]{% for var in vars %}
     static var {{ var.name }}: String {
         let encoded: [UInt8] = [{% for encoded_chunk in var.value %}
            {% for encoded in encoded_chunk %}{{ encoded }}, {% endfor %}{% endfor %}
         ]
         return decode(encoded, cipher: salt)
     }
     {% endfor %}
     {% for environment in environments %}
     static var {{ environment.name }}: String {
         let encoded: [UInt8] = [{% for encoded_chunk in environment.value %}
            {% for encoded in encoded_chunk %}{{ encoded }}, {% endfor %}{% endfor %}
         ]
         return decode(encoded, cipher: salt)
     }
     {% endfor %}
     static func decode(_ encoded: [UInt8], cipher: [UInt8]) -> String {
       String(decoding: encoded.enumerated().map { offset, element in
         element ^ cipher[offset % cipher.count]
       }, as: UTF8.self)
     }
    }
    """
}

private extension Data {
    var bytes: [UInt8] {
        return Array(self)
    }
}
