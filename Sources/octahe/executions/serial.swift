//
//  serial.swift
//  
//
//  Created by Kevin Carter on 6/25/20.
//

import Foundation

import SwiftSerial

class ExecuteSerial: Execution {
    var serialPort: SerialPort?

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)
    }

    override func connect() throws {
        self.serialPort = SerialPort(path: self.target!)
        self.serialPort!.setSettings(
            receiveRate: .baud9600,
            transmitRate: .baud9600,
            minimumBytesToRead: 1
        )
        try self.serialPort!.openPort()
    }

    override func close() {
        self.serialPort!.closePort()
    }

    override func probe() throws {
        logger.info("Environment options are irrelevant with serial ports.")
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String], chown: String?) throws {
        guard fromFiles.count > 1 else {
            throw RouterError.notImplemented(message: "Only one file can be written to a serial port")
        }
        let fromUrl = base.appendingPathComponent(fromFiles.first!)
        let fileData = try Data(contentsOf: fromUrl)
        _ = try self.serialPort?.writeData(fileData)
    }

    override func run(execute: String) throws {
        _ = try self.serialPort?.writeString(execute)
    }

    override func serviceTemplate(entrypoint: String) throws {
        preconditionFailure("This method is not supported")
    }
}
