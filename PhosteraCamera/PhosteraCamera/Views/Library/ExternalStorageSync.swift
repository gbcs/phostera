//
//  ExternalStorageSync.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/24/23.
//

import SwiftUI
import PhosteraShared

//Enumerate the contents of the personal library
//UI to copy them all to current storage device

struct ExternalStorageSyncView: View {
    @State var personalCopyList:[String] = []
    @State var completed:[String] = []
    @State var isCopying:Bool = false
    @State var working:String = ""
    @State var hasStarted:Bool = false
    
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
                            Text("\(value)")
                            Spacer()
                            Image(systemName: "checkmark.rectangle").foregroundStyle(.accent)
                        }
                    } else {
                        Text("\(value)").foregroundStyle(working == value ? .accent : .primary)
                    }
                }
            })
        }.onAppear() {
            self.personalCopyList = loadListToCopy()
        }.navigationTitle("External Media Sync")
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
                    if LibraryController.copyItemToExternalStorage(takeUUID: f) {
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
    
    func loadListToCopy() -> [String] {
        var list:[String] = []
        let docDirectory = URL.documentsDirectory
       
        do {
            let directories = try FileManager.default.contentsOfDirectory(at: docDirectory, includingPropertiesForKeys: nil)
            for d in directories {
                let v = d.lastPathComponent
                if v == "logs" { continue }
                if d.hasDirectoryPath {
                    if checkDirectory(url: d) {
                        list.append(v)
                    }
                }
            }
        } catch {
            Logger.shared.error("Error in loadListToCopy")
        }
      
        return list
    }
}
