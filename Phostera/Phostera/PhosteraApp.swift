//
//  PhosteraApp.swift
//  Phostera
//
//  Created by Gary Barnett on 8/6/23.
//

import SwiftUI
import SwiftData

@main
struct PhosteraApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Item.self)
    }
}
