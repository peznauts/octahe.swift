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
    class func buildRawConfigs(files:Array<String>) throws -> [(key: String, value: String)] {
        var rawConfigs: [String] = []
        var configOptions: [(key: String, value: String)] = []
        for file in files {
            do {
                let configData = try String(contentsOfFile: file)
                rawConfigs.insert(configData, at: 0)
            } catch {
                throw FileParserError.FileReadFailure(filePath: file)
            }
        }
        for rawconfig in rawConfigs {
            let lines = rawconfig.split(whereSeparator: \.isNewline)
            // TODO(cloudnull): the line parser should handle a multi-line VERB.
            for line in lines {
                let trimmed = line.replacingOccurrences(of: "#.*", with: "", options: [.regularExpression])
                let cleanedLine = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedLine.isEmpty {
                    let verbArray = cleanedLine.split(separator: " ", maxSplits: 1).map(String.init)
                    do {
                        let data = verbArray[1].data(using: .utf8)!
                        let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as! Array<String>
                        let joined = json.joined(separator: " ")
                        configOptions.append((key: verbArray[0], value: String(joined)))
                    } catch {
                        configOptions.append((key: verbArray[0], value: verbArray[1]))
                    }
                }
            }
        }
        return configOptions
    }
}
