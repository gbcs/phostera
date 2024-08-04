//
//  TagView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/11/23.
//

import SwiftUI

struct TagView: View {
    var tagName: String
    var backgroundColor: Color = Color.blue

    var body: some View {
        TagLabel(tagName: tagName)
            .frame(height: 20) 
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(.primary)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct TagLabel: UIViewRepresentable {
    var tagName: String
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = tagName
    }
}
