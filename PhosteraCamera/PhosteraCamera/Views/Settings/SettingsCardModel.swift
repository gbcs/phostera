//
//  SettingsCard.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import Foundation
class SettingsCardModel {
    let title:String
    let footer:String
    let imageName:String
    
    init(title: String, footer: String, imageName: String) {
        self.title = title
        self.footer = footer
        self.imageName = imageName
    }
}
