//
//  ExternalStorageViewer.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/3/23.
//

import SwiftUI
import AVFoundation
import PhosteraShared

struct FileItem: Identifiable, RandomAccessCollection, BidirectionalCollection {
    var id: Int32
    var name: String
    var children: [FileItem]?
    var footageType: FootageType?
    var fullPath:String
    
    mutating func determineFootageType() {
        footageType = .video
    }
    
    typealias Index = Array<FileItem>.Index
    typealias Element = FileItem
    typealias SubSequence = ArraySlice<FileItem>
    
    var startIndex: Index {
        return children?.startIndex ?? 0
    }
    
    var endIndex: Index {
        return children?.endIndex ?? 0
    }
    
    subscript(bounds: Range<Index>) -> SubSequence {
        guard let children = children else { return [] }
        return children[bounds]
    }
    
    func index(before i: Index) -> Index {
        return i - 1
    }
    
    func index(after i: Index) -> Index {
        return i + 1
    }
    
    subscript(position: Array<FileItem>.Index) -> FileItem {
         _read {
             guard let children = children, position < children.endIndex else {
                 fatalError("Index out of range")
             }
             yield children[position]
         }
     }
}

var fileSystemDataProviderFileIndex:Int32 = 0

class FileSystemDataProvider: ObservableObject {
    @Published var rootItem: FileItem
    private var nextID: Int32 = 0

     func walk(path: String) -> [FileItem]? {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            return contents.compactMap { item in
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
                if isDir.boolValue {
                    fileSystemDataProviderFileIndex += 1
                    return FileItem(id: fileSystemDataProviderFileIndex, name: item, children: walk(path: itemPath), fullPath: itemPath)
                } else {
                    fileSystemDataProviderFileIndex += 1
                    var fileItem = FileItem(id: fileSystemDataProviderFileIndex, name: item, children: nil, fullPath: itemPath)
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
            self.rootItem = FileItem(id: fileSystemDataProviderFileIndex, name: rootPath.path, children: walk(path: rootPath.path), fullPath: rootPath.path)
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
        rootItem = FileItem(id: 0, name: "", fullPath: "")
    }
    
    func onItemSelected(item: FileItem) {
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
    var item: FileItem
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
    var items: [FileItem]
    @State var doImportItem:Bool = false
    @State var importItem:FileItem?
    
    var body: some View {
        List(items) { item in
            if let children = item.children, !children.isEmpty {
                NavigationLink(destination: DirectoryView(items: children)) {
                    FileRow(item: item)
                }
            } else {
                FileRow(item: item).onTapGesture {
                    Logger.shared.info("tapped on: \(item.name) - \(item.fullPath)")
                    importItem = item
                    doImportItem.toggle()
                }
            }
        }.sheet(isPresented: $doImportItem, content: {
            ImportMediaView(fileItem:$importItem)
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
