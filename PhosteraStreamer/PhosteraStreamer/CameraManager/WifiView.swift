//
//  WifiView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/30/23.
//

import Foundation
import SwiftUI
import PhosteraShared

//Display a WIFI QRCode

struct WifiView: View {
    @State var qrImage:UIImage?
    @State var currentProject:StreamProjectModel?
    @State var updateToggle:Bool = false
    @State var showQrTagOrText:Bool = true
    
    var body: some View {
        ZStack {
            Color.black
            VStack {
                if updateToggle || !updateToggle {
                    if showQrTagOrText {
                        if let qrImage {
                            Image(uiImage: qrImage).resizable().aspectRatio(contentMode: .fit).frame(minWidth: 250, idealWidth: 250, maxWidth: .infinity, minHeight: 250, idealHeight: 250, maxHeight: .infinity, alignment: .center)
                        } else {
                            Spacer()
                        }
                    } else {
                        Spacer(minLength: 50)
                        Text("WIFI")
                        Text("")
                        Text("\(currentProject?.wifiSSID ?? "MyWifiSSIDHERE")").font(.headline)
                        Spacer(minLength: 50)
                        Text("Password")
                        Text("")
                        Text("\(currentProject?.wifiPassword ?? "MYPASSHERESURE")").font(.headline)
                        Spacer(minLength: 50)
                    }
                }
            }.onTapGesture {
                showQrTagOrText.toggle()
            }
        }.onAppear() {
//            Task {
//                let project = await ProjectService.shared.currentProject()
//                DispatchQueue.main.async {
//                    qrImage = QRCode.generateQRCode(from: "http://localhost/")
//                    updateToggle.toggle()
//                }
//            }
        }
    }
    //wifi:\(project.wifiSSID):\(project.wifiPassword)
    func generatePairCode() -> String {
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let startIndex = uuid.startIndex
        let endIndex = uuid.index(uuid.startIndex, offsetBy: 4)
        return String(uuid[startIndex..<endIndex])
    }
}
