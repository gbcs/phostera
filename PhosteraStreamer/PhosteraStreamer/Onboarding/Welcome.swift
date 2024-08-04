//
//  Welcome.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/28/23.
//

import SwiftUI

enum OnboardingRoute: Int {
    case permission
}
struct WelcomePageView: View {
    @State var path: [OnboardingRoute] = [OnboardingRoute]()
    @Environment(\.dismiss) private var dismiss
    
    var appIcon:UIImage? =  UIImage(named: "AppIcon", in: .main, compatibleWith: UITraitCollection(displayScale: 2.0))
  
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack() {
                    if let appIcon {
                        if let roundedIcon = appIcon.withRoundedCorners(radius: 4) {
                            Image(uiImage: roundedIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100, alignment: .top).padding(.top, 40)
                        }
                    }
                    Text("Phostera Streamer").font(.largeTitle)
                    Text("Stream the world around you.").font(.headline).frame(alignment: .leading).padding()
                    Text("Single purchase. Try before you buy.").font(.headline).frame(alignment: .leading)
                    Text("No ads, subscriptions or tracking.").font(.headline).frame(alignment: .leading)
                    Spacer(minLength: 20)
                    Text("Phostera Community Forum")
                    Text("https://community.phostera.com/").font(.headline).frame(alignment: .leading)
                    Spacer(minLength: 20)
                    NavigationLink("Continue", value: OnboardingRoute.permission).padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(10)
                    Spacer(minLength: 20)
                }
            }.navigationDestination(for: OnboardingRoute.self) { route in
                switch(route) {
                case .permission:
                    PermissionsPageView(path: $path)
                }
            }
        }
    }
}

