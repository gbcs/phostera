//
//  WelcomeView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/7/23.
//

import SwiftUI

struct WelcomePageView: View {
    var appIcon:UIImage? =  UIImage(named: "AppIcon", in: .main, compatibleWith: UITraitCollection(displayScale: 2.0))

    @State var path: [OnboardingRoute] = [OnboardingRoute]()
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                //backgroundGradient.ignoresSafeArea()
                VStack() {
                    if let appIcon {
                        if let roundedIcon = appIcon.withRoundedCorners(radius: 4) {
                            Image(uiImage: roundedIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100, alignment: .top).padding(.top, 40)
                        }
                    }
                    Text("Phostera Camera").font(.largeTitle).padding(.bottom)
                    Spacer()
                    Text("Free. No charge. Enjoy!").font(.headline).frame(alignment: .leading)
                    Text("No ads, no subscription, no tracking.").font(.headline).frame(alignment: .leading)
                    Spacer()
                    Text("Phostera Community Forum")
                    Text("https://community.phostera.com/").font(.headline).frame(alignment: .leading).padding(.top)
                    Spacer()
                    NavigationLink("Continue", value: OnboardingRoute.permission).padding()
                        .background(.blue)
                        .foregroundColor(.primary)
                        .font(.headline)
                        .cornerRadius(10)
                    Spacer()
                }
            }.navigationDestination(for: OnboardingRoute.self) { route in
                switch(route) {
                case .permission:
                    PermissionsPageView(path: $path)
                case .about:
                    AboutPageView(path: $path)
                }
            }
        }
    }
}
