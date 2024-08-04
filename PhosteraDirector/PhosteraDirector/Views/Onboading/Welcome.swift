//
//  Welcome.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/30/23.
//

import SwiftUI
import PhosteraShared

enum OnboardingRoute: Int {
    case permission
}

struct WelcomePageView: View {
    var appIcon:UIImage? =  UIImage(named: "AppIcon", in: .main, compatibleWith: UITraitCollection(displayScale: 2.0))
    @Binding var path: [OnboardingRoute]
    var body: some View {
        GeometryReader { geo in
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
                    Text("Phostera Director").font(.largeTitle)
                    Text("Multi-camera director for Phostera Camera.").font(.headline).padding()
                    Text("Single purchase. Try before you buy.").font(.headline).frame(alignment: .leading).foregroundColor(.primary)
                    Text("No ads, subscriptions or tracking.").font(.headline).frame(alignment: .leading).foregroundColor(.primary)
                    Spacer()
                    Text("Phostera Community Forum")
                    Text("https://community.phostera.com/").font(.headline).frame(alignment: .leading).foregroundColor(.primary)
              
                    Spacer()
                    NavigationLink("Continue", value: OnboardingRoute.permission).padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(10)
                }
            }.navigationDestination(for: OnboardingRoute.self) { route in
                switch(route) {
                case .permission:
                    PermissionsPageView(path: $path)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

