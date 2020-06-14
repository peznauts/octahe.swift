//
//  mixin.swift
//  
//
//  Created by Kevin Carter on 6/11/20.
//

import Foundation


func PlatformArgs() -> Dictionary<String, String> {
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


func BuildDictionary(filteredContent: [(key: String, value: String)]) -> Dictionary<String, String> {
    func Trimmer(item: Substring, trimitems: CharacterSet = ["\""]) -> String {
        let cleanedItem = item.replacingOccurrences(of: "\\ ", with: " ")
        return cleanedItem.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: trimitems)
    }
    func matches(regex: String, text: String) -> Array<String> {
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
            print(RouterError.MatchRegexError(message: error.localizedDescription))
            return []
        }
    }

    let data = filteredContent.map{$0.value}.reduce(into: [String: String]()) {
        var argArray: Array<Array<Substring>> = []
        if $1.contains("=") {
            let regexArgsMap = matches(regex: "(\\w+)=(.+\"|.+\\s|\\w+)", text: $1)
            for arg in regexArgsMap {
                argArray.append(arg.split(separator: "=", maxSplits: 1))
            }
        } else {
            argArray.append($1.split(separator: " ", maxSplits: 1))
        }
        for itemSet in argArray {
            if let key = itemSet.first, let value = itemSet.last {
                let trimmedKey = Trimmer(item: key)
                let trimmedValue = Trimmer(item: value, trimitems: ["\"", "\\"])
                $0[trimmedKey] = trimmedValue
            }
        }
    }
    return data
}


extension String {
    var isInt: Bool {
        return Int(self) != nil
    }
}
