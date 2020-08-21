import Foundation

public struct Random {
    #if os(Linux)
        static var initialized = false
    #endif

    public static func generate(_ upperBound: Int) -> Int {
        #if os(Linux)
            if !Random.initialized {
                srandom(UInt32(time(nil)))
                Random.initialized = true
            }
            return Int(random() % upperBound)
        #else
            return Int(arc4random_uniform(UInt32(upperBound)))
        #endif
    }
}

public func randomText(_ length: Int, justLowerCase: Bool = false, whitespace: Bool = false) -> String {
    var chars = [UInt8]()

    while chars.count < length {
        let char = CharType.random(justLowerCase, whitespace).randomCharacter()
        if char == 32, (chars.last ?? 0) == char {
            // do not allow two consecutive spaces
            continue
        }
        chars.append(char)
    }
    return String(bytes: chars, encoding: .ascii)!
}

private enum CharType: Int {
    case LowerCase, UpperCase, Digit, Space

    func randomCharacter() -> UInt8 {
        switch self {
        case .LowerCase:
            return UInt8(Random.generate(26)) + 97
        case .UpperCase:
            return UInt8(Random.generate(26)) + 65
        case .Digit:
            return UInt8(Random.generate(10)) + 48
        case .Space:
            return 32
        }
    }

    static func random(_ justLowerCase: Bool, _ allowWhitespace: Bool) -> CharType {
        if justLowerCase {
            return .LowerCase
        } else {
            return CharType(rawValue: Int(Random.generate(allowWhitespace ? 4 : 3)))!
        }
    }
}
