//
//  PreviewRepresentable.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/16/23.
//

import Foundation
import SwiftUI
import UIKit
import MetalKit
import Combine

struct PreviewViewRep: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewMetalView {
        return MetalTool.shared.getDisplayView()!
    }

    func updateUIView(_ uiView: PreviewMetalView, context: Context) {

    }
}

