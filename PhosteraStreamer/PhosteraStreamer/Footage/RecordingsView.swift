//
//  RecordingsView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/9/23.
//

import Foundation

import SwiftUI
import PhosteraShared

struct RecordingsView: View {
    var project:StreamProjectModel
    @Environment(\.dismiss) private var dismiss
    
    @State var recordingList:[URL] = []
    
    func titleFor(url:URL) -> String {
        var title = ""
        var fileSize:UInt64 = 0
        var creationDate:Date = .now
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path()) {
            fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
            creationDate = attr[FileAttributeKey.creationDate] as? Date ?? .now
        }

        title.append(DateService.shared.dateTimeStamp(date: creationDate))
        title.append(" ")
        title.append("\(fileSize)")
        
        return title
    }
    
    func deleteRecording(at offsets: IndexSet) {
        offsets.forEach { index in
            let f = recordingList[index]
            let caf = f.appendingPathExtension("caf")
            try? FileManager.default.removeItem(at: caf)
            try? FileManager.default.removeItem(at: f)
        }
        recordingList = listRecordings()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Recordings") {
                    ForEach($recordingList, id: \.self) { $recording in
                        Text(titleFor(url: recording))
                    }.onDelete(perform: deleteRecording)
                }
            }.onAppear() {
                recordingList = listRecordings()
            }
        }.navigationTitle("Recordings for \(project.title)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing, content: {
                    NavigationLink {
                        ExternalStorageSyncView(project: project)
                    } label: {
                        Image(systemName: "externaldrive").resizable().frame(maxWidth: 30, maxHeight:30)
                    }
                })
            }
    }
    
    func listRecordings() -> [URL] {
        let fm = FileManager.default
        let url = URL.documentsDirectory
            .appending(path: project.id, directoryHint: .isDirectory)
        
        if let list = try? fm.contentsOfDirectory(at: url, 
                                                  includingPropertiesForKeys: [.fileSizeKey],
                                                  options: .skipsSubdirectoryDescendants) {
            return list.filter { url in
                url.pathExtension == "mov"
            }
        }
        
        return []
    }
}


