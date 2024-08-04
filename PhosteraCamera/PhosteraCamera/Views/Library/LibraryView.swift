//
//  WelcomeView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/7/23.
//

import SwiftUI
import PhosteraShared

extension URL {
    func loadImage(_ image: inout UIImage?) {
        if let data = try? Data(contentsOf: self), let loaded = UIImage(data: data) {
            image = loaded
        } else {
            image = nil
        }
    }
    func saveImage(_ image: UIImage?) {
        if let image = image {
            if let data = image.jpegData(compressionQuality: 1.0) {
                try? data.write(to: self)
            }
        } else {
            try? FileManager.default.removeItem(at: self)
        }
    }
}

func imageForFileStr(fileStr:String) -> UIImage {
    var u:UIImage?

    if let x:URL = LibraryController.thumbnailUrlforFileUrl(fileUrl: URL(filePath: fileStr)) {
        x.loadImage(&u)
    }

    return u ?? UIImage()
}

struct VideoListItemView: View {
    @Binding var pathLibrary:[LibraryRoute]
    @Binding var item:FootageFileItem
    
    var body: some View {
        HStack {
            VStack {
                Image(uiImage: imageForFileStr(fileStr: item.url))
                    .resizable()
                    .frame(width: 100, height: 100*(16/9))
                    .scaledToFit()
            }.frame(height: 100)
            VStack {
                Text("Right Meta")
            }.frame(height: 100)
        }
        HStack {
            Text("Lower Area")
        }
    }
}

struct PhotoListItemView: View {
    @Binding var pathLibrary:[LibraryRoute]
    @Binding var item:FootageFileItem
    var body: some View {
        Text("photo")
    }
}

enum LibraryDateRange: String, CaseIterable, Identifiable, CustomStringConvertible {
    case today
    case yesterday
    case earlier
    
    var id: Self { self }
    var description: String {
        switch self {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .earlier:
            return "Earlier"
        }
    }
}

struct LibraryPageView: View {
    @Environment(\.dismiss) private var dismiss
    @State var pathLibrary: [LibraryRoute] = [LibraryRoute]()
    @State var libraryItems:[FootageFileItem] = []
   
    @State var dateRange:LibraryDateRange = .today
    @State var isLoadingFileItems:Bool = true
    
    let queue:DispatchQueue = DispatchQueue(label: "loadLibrary", qos: .userInitiated)
    
    var body: some View {
        NavigationStack() {
            ZStack {
                if isLoadingFileItems {  ProgressView.init { }  } else {
                    VStack {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "arrowshape.backward.circle").resizable().frame(maxWidth: 30, maxHeight:30)
                            }
                            .buttonBorderShape(.roundedRectangle)
                            
                            Picker("Date Range", selection: $dateRange) {
                                Text("Today").tag(LibraryDateRange.today)
                                Text("Yesterday").tag(LibraryDateRange.yesterday)
                                Text("Earlier").tag(LibraryDateRange.earlier)
                            }.pickerStyle(.segmented)
                            
                            NavigationLink {
                                ExternalStorageSyncView()
                            } label: {
                                Image(systemName: "externaldrive").resizable().frame(maxWidth: 30, maxHeight:30)
                            }.disabled(!checkExternalMedia())
                        }
                        LibraryListView(pathLibrary: $pathLibrary, items: $libraryItems, dateRange: $dateRange)
                    }
                }
            }
        }.onChange(of: dateRange, { oldValue, newValue in
            Task {
                self.libraryItems = await LibraryController.getItemList(category: dateRange)
                   
                DispatchQueue.main.async {
                    self.isLoadingFileItems = false
                }
            }
        })
        .onAppear {
            Task {
                self.libraryItems = await LibraryController.getItemList(category: .today)
                   
                DispatchQueue.main.async {
                    self.isLoadingFileItems = false
                }
            }
        }
    }
    
    func checkExternalMedia() -> Bool {
        var answer:Bool = false
        for storage in ExternalStorageService.storageList() {
            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                if mediaURL.startAccessingSecurityScopedResource() {
                    mediaURL.stopAccessingSecurityScopedResource()
                    answer = true
                    break
                }
            }
        }
        return answer
    }
    
}
