//
//  BuyView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/19/23.
//

import SwiftUI

struct BuyView: View {
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                List {
                    Section("Purchase Phostera Streamer") {
                        Text("One time purchase and 30 day trial available soon.").disabled(true)
                    }
                }.listStyle(.grouped)
                
            }
            .navigationTitle("Buy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
