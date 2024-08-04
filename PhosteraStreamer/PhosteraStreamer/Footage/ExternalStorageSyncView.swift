//
//  SyncRecordingsExternalStorage.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/1/23.
//

import SwiftUI
import PhosteraShared

//Enumerate the contents of the personal library
//UI to copy them all to current storage device

struct ExternalStorageSyncView: View {
    @State var personalCopyList:[URL] = []
    @State var completed:[URL] = []
    @State var isCopying:Bool = false
    @State var working:URL?
    @State var hasStarted:Bool = false
    @State var project:StreamProjectModel
    
    func titleFor(url:URL) -> String {
        var title = ""
        var fileSize:UInt64 = 0
        var creationDate:Date = .now
        
        let ext = url.pathExtension
        
        if ext == "mov" {
            title = "Video "
        } else if ext == "caf" {
            title = "Audio "
        }
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path()) {
            fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
            creationDate = attr[FileAttributeKey.creationDate] as? Date ?? .now
        }

        title.append(DateService.shared.dateTimeStamp(date: creationDate))
        title.append(" ")
        title.append("\(fileSize)")
        
        return title
    }
    
    static func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        // Check if the source is a directory
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Create the destination directory if it doesn't exist
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                
                // Get the contents of the source directory
                let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: [])
                
                // Recursively copy each item in the source directory
                for item in contents {
                    let destinationItemURL = destinationURL.appendingPathComponent(item.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: destinationItemURL.path()) {
                        try ExternalStorageSyncView.copyItem(at: item, to: destinationItemURL)
                    }
                }
            } else {
                // Copy the file from source to destination
                if !FileManager.default.fileExists(atPath: destinationURL.path()) {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            }
        }
    }
    
    func copyItemToExternalStorage(filePath:String) -> Bool {
        var found:Bool = false
        for storage in ExternalStorageService.storageList() {
            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                if mediaURL.startAccessingSecurityScopedResource() {
                  
                    try? FileManager.default.createDirectory(at: mediaURL
                        .appending(path: project.id, directoryHint: .isDirectory), withIntermediateDirectories: true)
                    
                    let source = URL.documentsDirectory
                        .appending(path: project.id, directoryHint: .notDirectory)
                        .appending(path: filePath, directoryHint: .notDirectory)
           
                    let destination = mediaURL
                        .appending(path: project.id, directoryHint: .notDirectory)
                        .appending(path: filePath, directoryHint: .notDirectory)
                    
                    do {
                        try ExternalStorageSyncView.copyItem(at: source, to: destination)
                    } catch {
                        Logger.shared.error("Error copying \(source) to \(destination) on storage \(mediaURL) - \(error.localizedDescription)")
                    }
            
                    mediaURL.stopAccessingSecurityScopedResource()
                    Logger.shared.info("Finished copying \(source) to \(destination) on storage \(mediaURL)")
                    found = true
                    break
                } else {
                    Logger.shared.error("Unable to access storage at \(mediaURL)")
                }
            }
        }
   
        return found
    }
    
    var body: some View {
        Form {
            if isCopying {
                Section("Progress", content: {
                    ProgressView(value: Float(completed.count), total: Float(personalCopyList.count))
                })
            }
            Section("List to Copy", content: {
                ForEach(personalCopyList, id:\.self) { value in
                    if completed.contains(value) {
                        HStack {
                            Text("\(titleFor(url:value))")
                            Spacer()
                            Image(systemName: "checkmark.rectangle").foregroundStyle(.accent)
                        }
                    } else {
                        Text("\(titleFor(url:value))").foregroundStyle(working == value ? .accent : .primary)
                    }
                }
            })
        }.onAppear() {
            self.personalCopyList = loadListToCopy()
        }.navigationTitle("Backup Stream Recordings")
            .navigationBarItems(
                trailing:
                    Button("Start") {
                        if !isCopying {
                            hasStarted = true
                            isCopying = true
                            doCopies()
                        }
                    }).disabled(hasStarted)
    }
    
    func doCopies() {
        //Get next not-completed item from personal copy list, then copy it.
        //Update completed(on main thread), call us again if we have another
        Task {
            for f in personalCopyList {
                if !completed.contains(f) {
                    DispatchQueue.main.async {
                        working = f
                    }
                    if copyItemToExternalStorage(filePath: f.lastPathComponent) {
                        DispatchQueue.main.async {
                            completed.append(f)
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                isCopying.toggle()
            })
        }
    }
    
    func checkDirectory(url:URL) -> Bool { //See if there is a directory in here, this means it's a project not personal
        if let directories = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            for d in directories {
                if d.hasDirectoryPath { return false }
            }
        }
        return true
    }
    
    func loadListToCopy() -> [URL] {
        var list:[URL] = []
        let docDirectory = URL.documentsDirectory
            .appending(component: project.id, directoryHint: .isDirectory)
       
        do {
            let directories = try FileManager.default.contentsOfDirectory(at: docDirectory, includingPropertiesForKeys: nil)
            list = directories.sorted(by: { lURL, rURL in
                lURL.lastPathComponent > rURL.lastPathComponent
            })
        } catch {
            Logger.shared.error("Error in loadListToCopy")
        }
      
        return list
    }
}
