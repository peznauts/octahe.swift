//
//  fileParse.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation


enum FileParserError: Error {
    case FileReadFailure(filePath: String)
}

class FileParser {
    class func buildRawConfigs(files:Array<String>) throws -> String {
        var rawConfigs: [String] = []
        for file in files {
            do {
                let configData = try String(contentsOfFile: file)
                rawConfigs.insert(configData, at: 0)
            } catch {
                throw FileParserError.FileReadFailure(filePath: file)
            }
        }
        var trimmedList = [String]()
        for rawconfig in rawConfigs {
            let trimmed = rawconfig.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                trimmedList.append(trimmed)
            }
        }
        let joined = trimmedList.joined(separator: "\n")
        return joined
    }
}
