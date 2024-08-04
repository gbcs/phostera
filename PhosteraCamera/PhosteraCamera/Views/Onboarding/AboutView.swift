//
//  WelcomeView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/7/23.
//

import SwiftUI

struct AboutPageView: View {
    @Binding var path: [OnboardingRoute]
    var body: some View {
        ZStack {
            VStack() {
                Text("Phostera Camera Server").font(.headline)
                
                Spacer()
                
                Text("This app is designed to work with Phostera Streamer and Phostera Director over a network.")
                
                Spacer()
                
                Text("Do you wish to allow others to connect to this app and use the camera?").font(.subheadline)
                
                Spacer()
                
                Button {
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.Onboarding.complete, object: nil) }
                } label: {
                    Text("Yes; I want to use the related apps on my device(s).").frame(minHeight: 50)
                }.buttonStyle(.borderedProminent).foregroundColor(.primary).tint(.blue)
                
                Spacer()
                
                Button {
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.Onboarding.complete, object: nil) }
                } label: {
                    Text("Yes; someone asked me use this app with them.").frame(minHeight: 50)
                }.buttonStyle(.borderedProminent).foregroundColor(.primary).tint(.blue)
                
                Spacer()
                
                Button {
                    SettingsService.shared.settings.runServer = false
                    SettingsService.shared.save()
                    ServerKeys.stopServer()
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.Onboarding.complete, object: nil) }
                } label: {
                    Text("No; use the camera just as a camera.").frame(minHeight: 50)
                }.buttonStyle(.borderedProminent).foregroundColor(.primary).tint(.blue)
       
                Spacer()
                
                Text("Note: You can change this at any time in the Options menu under the Server option.  This app does not connect to the Internet. It listens only to devices around you and makes an effort to be secure.")
            
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}
