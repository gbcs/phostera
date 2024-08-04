//
//  LibraryListView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/17/23.
//

import Foundation
import SwiftUI
import PhosteraShared

struct LibraryListView: View {
    @Binding var pathLibrary: [LibraryRoute]
    @Binding var items:[FootageFileItem]
    @State var selectedItem:FootageFileItem?
    @Binding var dateRange:LibraryDateRange
    
    let dateFormatter = DateFormatter()

    @State private var scrollSelection:ObjectIdentifier?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack {
                    VStack {
                        if ($items.isEmpty) {
                            switch(dateRange) {
                            case .today:
                                ContentUnavailableView.init("Empty", systemImage: "video.badge.plus", description: Text("Nothing to see here. Shoot some video!"))
                            case .yesterday:
                                ContentUnavailableView.init("Empty", systemImage: "video.badge.plus", description: Text("Nothing from yesterday here."))
                            case .earlier:
                                ContentUnavailableView.init("Empty", systemImage: "video.badge.plus", description: Text("Nothing in the backlog. Your camera thanks you."))
                            }
                        } else {
                            ScrollViewReader { proxy in
                                HStack {
                                    ScrollView(.vertical) {
                                        LazyVStack {
                                            ForEach($items) { $item in
                                                Text("\(DateService.shared.hourMinFrom(date: item.creationDate))").onTapGesture {
                                                    scrollSelection = item.id
                                                }
                                            }
                                        }
                                    }.frame(width: 100)
                                    
                                    ScrollView(.vertical) {
                                        LazyVStack {
                                            ForEach($items) { $item in
                                                if let i = LibraryController.getThumbnailImage(path: item.url) {
                                                    LibraryListItemView(pathLibrary: $pathLibrary, items: $items, selectedItem: $item, image: i).frame(minWidth: geo.size.width).id(item.id)
                                                        .background(Color(red: 1, green: 1, blue: 1, opacity: 0.1))
                                                        .cornerRadius(12)
                                                        .shadow(color: Color(.init(red: 0, green: 0, blue: 0, alpha: 0.16)), radius: 2, y: 3)
                                                } else {
                                                    ContentUnavailableView.init("Broken", systemImage: "video.slash", description: Text("A thumbnail was not able to be rendered for this asset."))
                                                        .background(Color(red: 1, green: 1, blue: 1, opacity: 0.1))
                                                        .cornerRadius(12)
                                                        .shadow(color: Color(.init(red: 0, green: 0, blue: 0, alpha: 0.16)), radius: 2, y: 3)
                                                        .onTapGesture(perform: {
                                                            
                                                        })
                                                }
                                            }.frame(width: geo.size.width, height: 200, alignment: .center)
                                        }
                                    }.onChange(of: scrollSelection, initial: false, { value, a  in
                                        proxy.scrollTo(a, anchor: .top)
                                    })
                                }
                                
                            }
                        }
                    }.listStyle(.plain)
                }
                
            }.onAppear {
            }
            
        }
    }
}
