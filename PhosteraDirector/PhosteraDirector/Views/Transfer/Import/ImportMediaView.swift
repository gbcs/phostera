//
//  ImportMediaView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/3/23.
//

import SwiftUI

struct ImportMediaView: View {
    @Binding var fileItem:FileItem?
    @Environment(\.dismiss) private var dismiss
    @State var importMode:Bool = false
    
    @State var progress:Double = 0.0
    
    @State var videoImporter:VideoImporter?
    
    func importVideo() {
        guard let fileItem else { return }
        let outURL = URL.documentsDirectory.appendingPathComponent("output.mov")
        if let inUrl = URL(string: fileItem.fullPath) {
            videoImporter = VideoImporter(inputURL: inUrl,
                                          targetFrameRate: 30,
                                          outputURL: outURL,
                                          progressHandler: { p in
                progress = p
            })
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack() {
                    Form {
                        if importMode {
                            Section("Importing", content: {
                                ProgressView("Converting", value:progress)
                            })
                        }
                        
                        Section(fileItem?.name ?? "", content: {
                            
                        })
                    }
                }
            } .navigationTitle("Import Media")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading, content: {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                        }
                        
                    })
                    
                    ToolbarItem(placement: .topBarTrailing, content: {
                        Button(action: {
                            importVideo()
                            importMode.toggle()
                        }) {
                            Text("Import")
                        }
                    })
                }
        }
    }
}

