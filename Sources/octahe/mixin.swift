//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/11/20.
//

import Foundation

import Crypto

import Logging

let logger = Logger(label: "octahe")

func platformArgs() -> [String: String] {
    // Sourced from local machine
    //    BUILDPLATFORM - platform of the node performing the build.
    //    BUILDOS - OS component of BUILDPLATFORM
    //    BUILDARCH - architecture component of BUILDPLATFORM
    //    BUILDVARIANT - variant component of BUILDPLATFORM
    var platform = [String: String]()
    #if os(Linux)
        platform["BUILDOS"] = "linux"
    #else
        platform["BUILDOS"] = "darwin"
    #endif
    #if arch(x86_64)
        platform["BUILDARCH"] = "amd64"
    #elseif arch(arm64)
        platform["BUILDARCH"] = "arm64"
    #endif
    platform["BUILDPLATFORM"] = platform["BUILDOS"]! + "/" + platform["BUILDARCH"]!
    return platform
}

func buildDictionary(filteredContent: [(key: String, value: String)]) -> [String: String] {
    func trimmer(item: Substring, trimitems: CharacterSet = ["\""]) -> String {
        let cleanedItem = item.replacingOccurrences(of: "\\ ", with: " ")
        return cleanedItem.strip.trimmingCharacters(in: trimitems)
    }

    func matches(text: String) -> [String] {
        let regex = "(?:\"(.*?)\"|(\\w+))=(?:\"(.*?)\"|(\\w+))"
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(
                in: text,
                range: NSRange(
                    text.startIndex...,
                    in: text
                )
            )
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            logger.warning("\(error.localizedDescription)")
            return []
        }
    }

    let data = filteredContent.map {$0.value}.reduce(into: [String: String]()) {
        var argArray: [[Substring]] = []
        if $1.contains("=") {
            let regexArgsMap = matches(text: $1)
            for arg in regexArgsMap {
                argArray.append(arg.split(separator: "=", maxSplits: 1))
            }
        } else {
            argArray.append($1.split(separator: " ", maxSplits: 1))
        }
        for itemSet in argArray {
            if let key = itemSet.first, let value = itemSet.last {
                let trimmedKey = trimmer(item: key)
                let trimmedValue = trimmer(item: value, trimitems: ["\"", "\\"])
                $0[trimmedKey] = trimmedValue
            }
        }
    }
    return data
}

extension Int32 {
    // String extension allowing us to evaluate if any string is actually an Int.
    var toString: String {
        return String(describing: self)
    }
}

extension String {
    // String extension allowing us to evaluate if any string is actually an Int.
    var isInt: Bool {
        return Int32(self) != nil
    }

    var isBool: Bool {
        return Bool(self) != nil
    }

    var strip: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sha1: String {
        // swiftlint:disable force_try
        let digest = try! SHA1.hash(self)
        return digest.hexEncodedString()
    }

    func toInt() throws -> Int32 {
        guard self.isInt else {
            throw RouterError.failedExecution(message: "\(self) could not be converted to Int32")
        }
        return Int32(self)!
    }

    func trunc(length: Int, trailing: String = " ...") -> String {
        if self.count <= length {
            return self
        }
        let truncated = self.prefix(length)
        return truncated + trailing
    }

    var escape: String {
        return self.replacingOccurrences(of: "\"", with: "\\\"")
    }

    var escapeQuote: String {
        return "\"\(self.escape)\""
    }
}

extension Array {
    func getNextElement(index: Int) -> Element? {
        let nextIndex = index + 1
        let isValidIndex = nextIndex >= 0 && nextIndex < count
        return isValidIndex ? self[nextIndex] : nil
    }
}
