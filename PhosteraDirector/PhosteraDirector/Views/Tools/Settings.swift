//
//  Settings.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/21/23.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack {
                Text("Settings View")
            }
        }.navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading, content: {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                    }
                })
            }
    }
}
