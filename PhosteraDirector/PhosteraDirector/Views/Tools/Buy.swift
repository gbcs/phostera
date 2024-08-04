//
//  Buy.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/14/23.
//

import Foundation
import SwiftUI

struct BuyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            List {
                Section("Purchase Phostera Director") {
                    Text("One time purchase and 30 day trial available soon.").disabled(true)
                }
            }
        }
        .navigationTitle("Buy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            Task {
               // await PT.shared.retrieveProducts()
            }
        }
    }
}
