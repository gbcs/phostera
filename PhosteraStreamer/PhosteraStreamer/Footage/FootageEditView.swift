
import SwiftUI
import PhosteraShared

struct FootageEditView: View {
    @Binding var footage:FootageModel
    @Environment(\.dismiss) private var dismiss
    @State var metadata:VideoMetadata?
    @State var currentProject:StreamProjectModel?
    @State var convertableProject:Bool = false
    
    @State var importMode:Bool = false
    @State var importModel = ImportViewModel()
    
    @State var timer:Timer?
    @State var status:Float = 0.0
    @State var viewUpdate:Bool = false
    @State var thumbnail:UIImage?
    @State var fileItem:DiskFileItem?
    @State var importCompletedSucessfully:Bool = false
    @State var badAsset:Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                if importMode {
                    Section(footage.name, content: {
                        ProgressView("Converting", value:status, total: 1.0)
                    })
                }
                
                Section("Asset Identity", content: {
                    TextField("Name", text: $footage.name)
                    Text("file: \(footage.url.lastPathComponent)")
                    Text("Type: \(String(footage.type.description))")
                })
                
                if (footage.type == .photo) {
                    let p = URL.documentsDirectory.appending(path: "footage").appendingPathComponent(footage.url.lastPathComponent)
                    Section("Photo", content: {
                        if let i = UIImage(contentsOfFile: p.path()) {
                            Image(uiImage: i).resizable().aspectRatio(contentMode: .fit).frame(height: 200)
                        } else {
                            Text("Image not found or not displayable as an image.")
                        }
                    })
                }
                
                if (footage.type == .video) {
                    if badAsset {
                        Section("Asset Status", content: {
                            Text("Unable to load metadata. This item is not functional.")
                        })
                    }
                    if let metadata {
                        Section("Metadata", content: {
                            HStack {
                                Text("Resolution")
                                Spacer()
                                Text("\(Int(metadata.resolution.width))x\(Int(metadata.resolution.height))")
                            }
                            
                            HStack {
                                Text("Framerate")
                                Spacer()
                                Text("\(Int(round(metadata.frameRate))) fps")
                            }
                            
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text("\(Int(round(metadata.duration))) seconds")
                            }
                            
                            HStack {
                                Text("Encoding")
                                Spacer()
                                Text("\(metadata.encoding)")
                            }
                        })
                        
                        if convertableProject {
                            Text("Not Playable: Framerate does not match project.").foregroundStyle(Color.yellow)
                        }
                        
                        if let thumbnail {
                            Section("Thumbnail", content: {
                                Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fit).frame(height: 200)
                            })
                        }
                    }
                    
                }
                
            }
        }.onAppear() {
            if importCompletedSucessfully {
                dismiss()
            } else {
                Task {
                    let project = await ProjectService.shared.currentProject()
                    let url = URL.documentsDirectory.appending(path: "footage").appendingPathComponent(footage.url.lastPathComponent)
                    if footage.type == .photo {
                        currentProject = project
                        fileItem = DiskFileItem(id: 42, name: url.lastPathComponent, fullPath: url.path())
                        fileItem?.footageType = .photo
                        fileItem?.name = footage.name
                        DispatchQueue.main.async {
                            viewUpdate.toggle()
                        }
                    } else if footage.type == .video {
                        let data = await FootageService.videoMetadata(from: url)
                        metadata = data
                        thumbnail = FootageService.makeThumbnailFor(url: url)
                        DispatchQueue.main.async {
                            fileItem = DiskFileItem(id: 42, name: url.lastPathComponent, fullPath: url.path())
                            fileItem?.footageType = .video
                            fileItem?.name = footage.name
                            currentProject = project
                            
                            if let metadata {
                                let f:Int = Int(round(metadata.frameRate))
                                var fr:StreamFrameRate = .fr24
                                if f == 25 {
                                    fr = .fr25
                                } else if f == 30 {
                                    fr = .fr30
                                }
                                if fr != currentProject?.streamFrameRate {
                                    convertableProject = true
                                }
                                
                                if currentProject?.streamResolution == .v1920x1080 {
                                    if metadata.resolution.width != 1920 {
                                        convertableProject = true
                                    }
                                }
                            } else {
                                badAsset = true
                            }
                            viewUpdate.toggle()
                        }
                    }
                }
            }
        }.navigationTitle("Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading:
                    Button("Cancel") {
                        dismiss()
                    },
                trailing:
                    Button("Save") {
                        Task {
                            await FootageService.shared.add(footage: footage)
                            DispatchQueue.main.async {
                                dismiss()
                            }
                        }
                    })
    }
}


