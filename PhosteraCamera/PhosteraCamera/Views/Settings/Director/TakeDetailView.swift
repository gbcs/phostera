//
//  TakeDetailView.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/20/23.
//

import Foundation
import SwiftUI
import Combine
import PhosteraShared

struct TakeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var update:Bool = false
    @State var take:CameraTakeModel
    @State var thumbnail:UIImage?
    @State private var isDeletingSelectedItem = false
    @State private var marked:Bool = false
    
    func deleteSelectedItem() {
      
        let takeDirectory = URL.applicationSupportDirectory
            .appending(component: "takes", directoryHint: .isDirectory)
            .appending(component: take.projectUUID, directoryHint: .isDirectory)
        let takeFile = takeDirectory.appending(component: take.uuid, directoryHint: .notDirectory)
    
        do {
            try FileManager.default.removeItem(at: takeFile)
        } catch {
            Logger.shared.info("Unable to delete take file: \(String(describing: takeFile))")
        }

        let takeMediaDirectory = URL.documentsDirectory
            .appending(component: take.projectUUID, directoryHint: .isDirectory)
            .appending(component: take.uuid, directoryHint: .isDirectory)

        do {
            try FileManager.default.removeItem(at: takeMediaDirectory)
        } catch {
            Logger.shared.info("Unable to delete take file: \(String(describing: takeFile))")
        }

    }
    
    var body: some View {
        VStack {
            Form {
                Section("Actions", content: {
                    Button(marked ? "Unmark" : " Mark", action: {
                        marked.toggle()
                        take.marked = marked
                        CameraTakeService.shared.save(take: take)
                    })
                    
                    Button("Delete", action: {
                        isDeletingSelectedItem.toggle()
                    })
                })
                if let thumbnail {
                    Section("Preview", content: {
                        Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 200)
                    })
                }
            }
        }
        .alert("Delete Item", isPresented: $isDeletingSelectedItem) {
            Button("OK", role: .destructive ) {
                self.deleteSelectedItem()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear() {
          thumbnail = thumbnailForTake(take: take)
            marked = take.marked
        }.frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity, minHeight: 200, idealHeight: 400, maxHeight: .infinity, alignment: .center)
            .navigationTitle(takeTitle(take: take)).navigationBarTitleDisplayMode(.inline)
    }
    
    func thumbnailForTake(take:CameraTakeModel) -> UIImage? {
        let takeDirectory = URL.documentsDirectory
            .appending(component: take.projectUUID, directoryHint: .isDirectory)
            .appending(component: take.uuid, directoryHint: .isDirectory)
        
        
        if let list = try? FileManager.default.contentsOfDirectory(atPath: takeDirectory.path()) {
            for item in list {
                if item.contains("thumbnail.png") {
                    if let data = try? Data(contentsOf: takeDirectory.appending(component: item)) {
                        return UIImage(data: data)
                    }
                }
            }
        }
        
        return nil
    }
    
    func durationString(take:CameraTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func takeTitle(take:CameraTakeModel) -> String {
        return "Take:" + DateService.shared.dateTimeStamp(date: take.startTime)
    }
    
}


