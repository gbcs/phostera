//
//  PhotoDetailView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import SwiftUI
import AVKit
import SwiftUI
import PhosteraShared

struct ZoomableImageView: View {
    @GestureState private var zoomScale: CGFloat = 1.0
    @State private var storedZoomScale: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero
    @State private var storedDragOffset: CGSize = .zero

    let image: UIImage

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(zoomScale * storedZoomScale)
                .offset(x: dragOffset.width + storedDragOffset.width, y: dragOffset.height + storedDragOffset.height)
                .gesture(
                    MagnificationGesture().updating($zoomScale) { value, state, _ in
                        state = value.magnitude
                    }.onEnded { value in
                        storedZoomScale *= value.magnitude
                    }
                    .simultaneously(with:
                        DragGesture().updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }.onEnded { value in
                            storedDragOffset = CGSize(
                                width: value.translation.width + storedDragOffset.width,
                                height: value.translation.height + storedDragOffset.height
                            )
                        }
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathLibrary: [LibraryRoute]
    @Binding var selectedItem:FootageFileItem

    @State private var zoomScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack {
            let path = selectedItem.url
            if let image = LibraryController.getImageFromFile(path: path) {
                ZoomableImageView(image: image)
            }
        }
    }
}
