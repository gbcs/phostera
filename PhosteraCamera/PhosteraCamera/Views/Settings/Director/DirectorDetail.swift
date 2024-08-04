//
//  DirectorDetail.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/20/23.
//

import Foundation
import SwiftUI
import PhosteraShared

struct DirectorDetailPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathSettings: [SettingsRoute]
    @Binding var director:DirectorModel
    @State var redraw:Bool
    @State var userWantsToDelete:Bool = false
    @Binding var directorList:[DirectorModel]
    
    var body: some View {
        ZStack {
            //backgroundGradient.ignoresSafeArea()
            VStack() {
                List() {
                    Section("Identity") {
                        HStack {
                            Text("Title")
                            Spacer()
                            Text(director.title)
                        }
                        HStack {
                            Text("Id")
                            Spacer()
                            Text("\(director.uuid)")
                        }
                    }
                    Section("Actions") {
                        NavigationLink("View Takes", destination: {
                            TakeProjectList(director: $director)
                        }).foregroundStyle( CameraTakeService.shared.hasTakes(director: director) ? .accent : .primary )
                        
                        if !director.authorized {
                            Button(action: {
                                director.authorized.toggle()
                                DirectorService.shared.saveDirector(director: director)
                                self.redraw.toggle()
                            }, label: {
                                Text("Allow")
                            })
                        } else {
                            Button(action: {
                                director.blocked.toggle()
                                DirectorService.shared.saveDirector(director: director)
                                self.redraw.toggle()
                            }, label: {
                                director.blocked ? Text("Unblock") : Text("Block")
                            })
                        }
                        
                        Button(action: {
                            userWantsToDelete = true
                        }, label: {
                            Text("Delete")
                        })
                    }
                }
            }
        }.navigationTitle("Director/Streamer").navigationBarHidden(false).alert(isPresented: $userWantsToDelete) {
            Alert(title: Text("Delete"),
                  message: Text("This will delete the director/streamer, any associated modes and any saved footage filmed via those modes. Are you sure?"),
                  primaryButton: .destructive(Text("Yes")) {
                Logger.shared.info("User chose to delete director/streamer. \(director.debugDescription)")
                DirectorService.shared.deleteDirector(director: director)
                if let i = directorList.firstIndex(of: director) {
                    directorList.remove(at: i)
                }
                dismiss()
                
            }, secondaryButton: .cancel(Text("No")) {
            })
        }
    }
}

