//
//  PhosteraDirectorApp.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/4/23.
//

import SwiftUI

@main


struct PhosteraDirectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onAppear() {
                _ = try? ServerKeys.keysForServer()
            }
        }
    }
}
