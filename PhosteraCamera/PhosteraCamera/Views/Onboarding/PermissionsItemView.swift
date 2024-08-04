//
//  PermissionsListItem.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/12/23.
//

import SwiftUI


struct PermissionsItemView: View {
    var imageName:String
    var imageTitle:String
    var statusImage:String
    var statusColor:Color
    var detailText:String
    var body: some View {
        HStack {
            Image(systemName: imageName).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .leading)
            if imageName.compare("gear") != .orderedSame { //Skip the info button on the system settings without adding another property
                NavigationLink {
                    ZStack {
                        VStack {
                            Spacer()
                            Text("\(detailText)")
                                .font(.system(size: 24))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
                              
                            Spacer()
                        }
                    }
                } label: {
                    Image(systemName:"info.circle").resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            
            Text(imageTitle).frame(width: 180, height: 45, alignment: .leading).padding(.horizontal)
            
            Image(systemName: statusImage).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .trailing).foregroundColor(statusColor)
        }
    }
}
