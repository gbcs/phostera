//
//  CardView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/12/23.
//

import SwiftUI

struct SettingsCardView: View {
    @Binding var pathSettings: [SettingsRoute]
    @Binding var cardModel:SettingsCardModel
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: cardModel.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 70, idealWidth: 100, maxWidth: 120, minHeight: 30, idealHeight: 30, maxHeight: 30, alignment: .center)
                    .clipped()
                LazyVStack(alignment: .center, spacing: 0) {
                    Text(cardModel.title)
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                    
                    Text(cardModel.footer)
                        .font(.system(size: 10))
                }.frame(minWidth: 70, idealWidth: 100, maxWidth: 120, minHeight: 70, idealHeight: 70, maxHeight: 70, alignment: .center)
                    .padding(EdgeInsets(top: -10, leading: 0, bottom: 0, trailing: 0))
            }.frame(minWidth: 70, idealWidth: 100, maxWidth: 120, minHeight: 100, idealHeight: 100, maxHeight: 100, alignment: .center)
            
            
        }
    }

}
