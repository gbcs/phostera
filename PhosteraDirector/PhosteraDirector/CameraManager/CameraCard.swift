//
//  CameraCard.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/21/23.
//

import Foundation
import SwiftUI
import PhosteraShared

//
//  CameraCard.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/21/23.
//

import Foundation
import SwiftUI
import PhosteraShared

struct CameraCard: View {
    var camera:CameraModel
    @State var online:Bool = false
    @State var isSelected:Bool = false
    @State var updateView:Bool = false
    @State var allowtap:Bool = false
    var body: some View {
        ZStack {
            Color.white
            HStack {
                Image(systemName:  online ? "camera.fill" : "camera")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 30, idealWidth: 30, maxWidth: 30, minHeight: 30, idealHeight: 30, maxHeight: 30, alignment: .leading)
                    .imageScale(.small)
                    .foregroundColor( online ? .green : .gray)
                    .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 0))
                VStack {
                    if camera.isKnown() {
                        Text(camera.name).font(.caption2).foregroundColor(.black)
                        Text(camera.model).font(.caption2).foregroundColor(.black)
                    } else {
                        Text("\(camera.uuid)").font(.caption2).foregroundColor(.black)
                        Text("Unknown").font(.caption2).foregroundColor(.black)
                    }
                }.frame(width: 90, height: 50, alignment: .leading)
            }
        }.frame(width: 120, height: 50, alignment: .leading)
        .onReceive(PubCentral.shared.onlineUpdated) { (output) in
            online = CameraManager.shared.isUUIDOnline(uuid: camera.uuid)
        }.onAppear() {
            online = CameraManager.shared.isUUIDOnline(uuid: camera.uuid)
            isSelected = CameraManager.shared.availableUUIDs.contains(camera.uuid)
            updateView = !updateView
        }.onReceive(CameraManager.shared.$availableUUIDs) { output in
            isSelected = CameraManager.shared.availableUUIDs.contains(camera.uuid)
        }.border(isSelected ? Color.yellow : Color.clear, width: isSelected ? 4 : 0)
            
    }
}
