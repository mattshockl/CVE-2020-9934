//
//  main.swift
//  bypasstcc
//
//  Created by Matt Shockley on 2/25/20.
//  Copyright © 2020 Matt Shockley. All rights reserved.
//

import Foundation

let path = CommandLine.argc > 1 ? CommandLine.arguments[1] : (FileManager.default.homeDirectoryForCurrentUser.path + "/Documents")
let demo_file_name = "<<<<BYPASS>>>>"

BypassTCC.shared.run(exec_path: Bundle.main.executablePath!) { () -> Void in
    let tmp_file = path + "/\(demo_file_name)"
    
    // attempt to write a file to the protected directory
    do {
        print("### Writing temporary file to '\(tmp_file)' ###")
        
        try "Hello, world!".write(to: URL(fileURLWithPath: tmp_file), atomically: true, encoding: .utf8)
        print("> success!\n")
    } catch {
        print("> failed: \(error)\n")
    }
    
    // attempt to read a file from the protected directory
    do {
        print("### Reading temporary file from '\(tmp_file)' ###")
        
        let contents = try String(contentsOfFile: tmp_file)
        print("> \(contents)\n")
    } catch {
        print("> failed: \(error)\n")
    }
    
    // attempt to list all files within the protected directory
    do {
        let file_urls = try FileManager.default.contentsOfDirectory(atPath: path)
        print("### Listing files for '\(path)' ###")
        for file in file_urls {
            print("> " + file)
        }
        
        print("")
    } catch {
        print("> failed: \(error)\n")
    }
    
    // attempt to delete a file from the directory
    do {
        print("### Deleting temporary file from '\(tmp_file)' ###")
        
        try FileManager.default.removeItem(atPath: tmp_file)
        print("> success\n")
    } catch {
        print("> failed: \(error)\n")
    }
}

