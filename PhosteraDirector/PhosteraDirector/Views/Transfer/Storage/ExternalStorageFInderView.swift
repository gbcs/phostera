//
//  ExternalStorageFInderView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/29/23.
//

import Foundation
import UIKit
import SwiftUI
import CoreServices
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        var parent: DocumentPicker
        
        init(parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                Logger.shared.info("DocumentPicker picked: \(String(describing: urls.first?.path))")
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.documentPicked, object: nil, userInfo: ["url" : url]) }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
