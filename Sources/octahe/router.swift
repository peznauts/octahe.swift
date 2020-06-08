//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

func CoreRouter(parsedOptions:Octahe.Options, function:String) throws {
    let configFiles = try FileParser.buildRawConfigs(files: parsedOptions.configurationFiles)
    print("Running function:", function)
    print(configFiles)
}
