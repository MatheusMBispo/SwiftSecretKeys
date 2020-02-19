import Foundation

enum Secrets {
 private static let salt: [UInt8] = [
      71, 106, 51, 68, 99, 109, 87, 108, 53, 67, 
      51, 80, 119, 109, 54, 88, 50, 57, 55, 112, 
      57, 50, 116, 118, 52, 115, 79, 83, 85, 104, 
      84, 109, 
 ]
 
 static var API: String {
     let encoded: [UInt8] = [
        51, 15, 64, 48, 2, 3, 51, 3, 
     ]
     return decode(encoded, cipher: salt)
 }
 
 static func decode(_ encoded: [UInt8], cipher: [UInt8]) -> String {
   String(decoding: encoded.enumerated().map { offset, element in
     element ^ cipher[offset % cipher.count]
   }, as: UTF8.self)
 }
}