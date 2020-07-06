//
//  file.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

enum FileParserError: Error {
    case fileReadFailure(filePath: String)
}

struct LineIterator {
    var lines: IndexingIterator<[Substring]> = [].makeIterator()
}

struct DataJson: Decodable {
    let item: String
}

class FileParser {
    private var lineData = LineIterator()
    var configOptions: TypeEntrypointOptions = []

    init() {}

    func trimLine(line: String) -> String {
        let trimmed = line.replacingOccurrences(of: "#.*", with: "", options: [.regularExpression])
        var trimmedLine = trimmed.strip
        if trimmedLine.hasSuffix(" \\") {
            trimmedLine = trimmedLine.replacingOccurrences(of: "\\", with: "")
            if let nextLine = lineData.lines.next() {
                trimmedLine += trimLine(line: String(describing: nextLine))
            }
        }
        return trimmedLine
    }

    func lineParser(lines: [Substring]) {
        lineData.lines = lines.makeIterator()
        while let line = lineData.lines.next() {
            let cleanedLine = self.trimLine(line: String(describing: line))
            if !cleanedLine.isEmpty {
                let verbArray = cleanedLine.split(separator: " ", maxSplits: 1).map(String.init)
                if verbArray.count > 1 {
                    let stringitem = String(describing: verbArray[1])
                    logger.debug("\(stringitem)")
                    if stringitem.isInt {
                        self.configOptions.append((key: verbArray[0], value: stringitem))
                    } else if stringitem.isBool {
                        self.configOptions.append((key: verbArray[0], value: stringitem))
                    } else {
                        do {
                            logger.debug("Parsing JSON data type")
                            let data = stringitem.data(using: .utf8)!
                            let dataJsons = try JSONDecoder().decode([String].self, from: data)
                            logger.debug("JSON loaded")
                            let newStringItem: String = dataJsons.joined(separator: " ")
                            self.configOptions.append((key: verbArray[0], value: newStringItem))
                        } catch {
                            logger.debug("Catch all data type used.")
                            self.configOptions.append((key: verbArray[0], value: stringitem))
                        }
                    }
                }
            }
        }
    }

    func buildRawConfigs(files: [String]) throws -> [(key: String, value: String)] {
        var rawConfigs: [String] = []
        for file in files {
            logger.info("Parsing Targetfile \(file)")
            do {
                let configData = try String(contentsOfFile: file)
                rawConfigs.insert(configData, at: 0)
            } catch {
                logger.critical("Target file not found: \(file)")
                throw FileParserError.fileReadFailure(filePath: file)
            }
        }
        for rawconfig in rawConfigs {
            let lines = rawconfig.split(whereSeparator: \.isNewline)
            self.lineParser(lines: lines)
        }
        logger.info("Targetfile parsing complete")
        return self.configOptions
    }
}
