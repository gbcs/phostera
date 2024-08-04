//
//  TakeListView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/21/23.
//

import SwiftUI
import PhosteraShared
import Combine

struct TakeListView: View {
    var projectUUID:String
    var projectTitle:String
    var camera:CameraModel
    
    @State var takeList:[CameraTakeModel] = []
    @Environment(\.dismiss) private var dismiss
    @State var cancellables:[AnyCancellable] = []

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                List {
                    ForEach(takeList) { t in
                        NavigationLink {
                            TakeDetailView(take: t, camera: camera)
                        } label: {
                            Text("\(dateTimeStamp(take: t)) - \(durationString(take: t))").foregroundStyle( t.marked ? .accent : .primary)
                        }
                    }
                }
            }
        }.onReceive(PubCentral.shared.onlineUpdated) { (output) in
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            }
        }.onAppear() {
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            } else {
                subscribeToList()
                getTakeList()
            }
        }.navigationTitle("Take List for \(projectTitle)").navigationBarTitleDisplayMode(.inline)
    }
    
    func getTakeList() {
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                let request = CameraRequest(command: .takeList, uuid: camera.uuid, sesionKey: key, dataUUID: projectUUID)
                await connection.requestFromCamera(content: request)
            }
        }
    }
    
    func subscribeToList() {
        cancellables.removeAll()
        cancellables.append(PubCentral.shared.pubTakeListUpdated.receive(on: DispatchQueue.main).sink { notification in
            if let userInfo = notification.userInfo {
                if let list = userInfo["list"] as? Array<CameraTakeModel> {
                    takeList = list.sorted(by: { c1, c2 in
                        c1.startTime > c2.startTime
                    })
                }
            }
        })
    }

    func durationString(take:CameraTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func dateTimeStamp(take:CameraTakeModel) -> String {
        return DateService.shared.dateTimeStamp(date: take.startTime)
    }

}
