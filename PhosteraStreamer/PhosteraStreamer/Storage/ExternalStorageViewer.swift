//
//  ExternalStorageViewer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/4/23.
//

import SwiftUI
import AVFoundation
import PhosteraShared
import UniformTypeIdentifiers

var fileSystemDataProviderFileIndex:Int32 = 0

class FileSystemDataProvider: ObservableObject {
    @Published var rootItem: DiskFileItem
    private var nextID: Int32 = 0

     func walk(path: String) -> [DiskFileItem]? {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            return contents.compactMap { item in
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
                if isDir.boolValue {
                    fileSystemDataProviderFileIndex += 1
                    return DiskFileItem(id: fileSystemDataProviderFileIndex, name: item, children: walk(path: itemPath), fullPath: itemPath)
                } else {
                    fileSystemDataProviderFileIndex += 1
                    var fileItem = DiskFileItem(id: fileSystemDataProviderFileIndex, name: item, children: nil, fullPath: itemPath)
                    fileItem.determineFootageType()
                    return fileItem
                }
            }
        } catch {
            Logger.shared.error("Filesystem traversal error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func reset(rootPath:URL) {
        if rootPath.startAccessingSecurityScopedResource() {
            loadMetadata(rootPath: rootPath)
            fileSystemDataProviderFileIndex += 1
            self.rootItem = DiskFileItem(id: fileSystemDataProviderFileIndex, name: rootPath.path, children: walk(path: rootPath.path), fullPath: rootPath.path)
            rootPath.stopAccessingSecurityScopedResource()
        } else {
            Logger.shared.error("Unable to startAccessingSecurityScopedResource for \(rootPath)")
        }
    }
    
    func loadMetadata(rootPath:URL) {
        if let mediaData = FileManager.default.contents(atPath: rootPath.appending(path: "Phostera.media.metadata").path) {
            let decoder = JSONDecoder()
            do {
                let media = try decoder.decode(StorageMediaModel.self, from: mediaData)
                Logger.shared.info("loaded media metadata:\(media)")
            } catch {
                Logger.shared.error("loadMetadata: \(error.localizedDescription)")
            }
        }
    }

    init(rootPath: String) {
        rootItem = DiskFileItem(id: 0, name: "", fullPath: "")
    }
    
    func onItemSelected(item: DiskFileItem) {
        Logger.shared.error("Selected item: \(item.name), Type: \(item.footageType?.description ?? "Unknown")")
    }
}

class ExternalStorageViewModel: ObservableObject {
    @Published var dataProvider: FileSystemDataProvider
    
    init(rootPath: String) {
        self.dataProvider = FileSystemDataProvider(rootPath: rootPath)
    }
    
    func loadData(media: StorageMediaModel) {
        if let url = ExternalStorageManager.loadExernalStorage(media: media) {
            dataProvider.reset(rootPath: url)
        }
    }
}

struct FileRow: View {
    var item: DiskFileItem
    var body: some View {
        HStack {
            Image(systemName: item.children != nil ? "folder.fill" : "doc")
                .foregroundColor(item.children != nil ? .blue : .primary)
            Text(item.name)
                .font(.system(.body, design: .monospaced))
        }
    }
}


struct DirectoryView: View {
    var items: [DiskFileItem]
    @State var doImportVideo:Bool = false
    @State var doImportPhoto:Bool = false
    @State var importVideo:DiskFileItem?
    @State var importPhoto:DiskFileItem?
    @State var importCompletedSucessfully:Bool = false
    @State var picked:Bool = false
    
    func handleTap(item:DiskFileItem) {
        Logger.shared.info("tapped on: \(item.name) - \(item.fullPath)")
        if let utType = UTType(filenameExtension: (item.name as NSString).pathExtension) {
            if utType.isSubtype(of: .video) || utType.isSubtype(of: .movie) {
                importVideo = item
                doImportVideo.toggle()
            } else if (utType.isSubtype(of: .image)) {
                importPhoto = item
                doImportPhoto.toggle()
            }
        }
    }
    
    var body: some View {
        List(items) { item in
            if let children = item.children, !children.isEmpty {
                NavigationLink(destination: DirectoryView(items: children)) {
                    FileRow(item: item)
                }.disabled(item.name.hasPrefix("."))
            } else {
                FileRow(item: item).onTapGesture {
                   handleTap(item: item)
                }.disabled(item.name.hasPrefix("."))
            }
        }.sheet(isPresented: $doImportVideo, content: {
            ImportVideoView(fileItem:$importVideo, importCompletedSucessfully: $importCompletedSucessfully, picked: $picked)
        }).sheet(isPresented: $doImportPhoto, content: {
            ImportPhotoView(fileItem:$importPhoto)
        })
    }
}

class MainViewModel: ObservableObject {
    @Published var externalStorageViewModel: ExternalStorageViewModel?
    
    func loadData(media: StorageMediaModel) {
        if let url = ExternalStorageManager.loadExernalStorage(media: media) {
            self.externalStorageViewModel = ExternalStorageViewModel(rootPath: url.path)
            self.externalStorageViewModel?.dataProvider.reset(rootPath: url)
        }
    }
}

struct ExternalStorageViewer: View {
    @StateObject var viewModel = MainViewModel()
    @State var ready: Bool = false
    @State var media: StorageMediaModel

    var body: some View {
        ZStack {
            if ready, let rootChildren = viewModel.externalStorageViewModel?.dataProvider.rootItem.children {
                DirectoryView(items: rootChildren)
                    .navigationTitle("External Storage")
            }
        }.onAppear {
            SettingsService.shared.currentStorageMedia = media
            viewModel.loadData(media: media)
            ready = true
        }
    }
}
