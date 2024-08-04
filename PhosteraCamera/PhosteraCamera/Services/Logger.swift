//
//  Logger.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/27/23.
//

import Foundation
import PhosteraShared
import os.log

struct Logger {
    static var shared = Logger()
    private var fileURL:URL
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter
    
    init() {
        let filename = "camera_" + DateService.shared.filenameForCurrentDateTime()
        
        let directory = URL.documentsDirectory
            .appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let url = URL.documentsDirectory
            .appendingPathComponent("logs")
            .appendingPathComponent(filename)
            .appendingPathExtension("log").standardizedFileURL
        
        fileURL = URL(filePath: url.path())
        
        FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    private func logMessage(_ message: String, type: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(type)] \(message)\n"
        
        os_log("%@", logMessage)
        
        writeToFile(logMessage)
    }
    
    private func writeToFile(_ message: String) {
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = message.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    }
    
    func info(_ message: String) {
        logMessage(message, type: "INFO")
    }
    
    func error(_ message: String) {
        logMessage(message, type: "ERROR")
    }
    
    func warn(_ message: String) {
        logMessage(message, type: "WARN")
    }
    
}
