//
//  ContentView.swift
//  Phostera
//
//  Created by Gary Barnett on 8/6/23.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    var body: some View {
        NavigationStack {
            List {
                Text("Featured Video #1").frame(height: 200)
                Text("Featured Video #2").frame(height: 200)
                Text("Featured Video #3").frame(height: 200)
                Text("Featured Video #4").frame(height: 200)
            }.navigationTitle("Featured Videos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading, content: {
                    Button(action: filter) {
                        Label("Phostera Info and Help", systemImage: "")
                    }
                })
                
                ToolbarItem(placement: .navigationBarTrailing, content: {
                    Button(action: filter) {
                        Label("Local Stream", systemImage: "")
                    }
                })
            }
        }
    }
    
    private func filter() {
        withAnimation {
    
        }
    }

    private func localStreams() {
        withAnimation {
    
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
