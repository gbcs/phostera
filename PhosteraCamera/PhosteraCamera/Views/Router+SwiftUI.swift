//
//  Router.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/11/23.
//

import SwiftUI

enum OnboardingRoute: Int {
    case permission
    case about
}

enum SettingsRoute: Int {
    case options
    case help
    case server
    case permissions
}

enum LibraryRoute: Int {
    case detail
}

enum NormalRoute: Int {
    case permission
    case settings
    case upgrade
    case library
    case camera
}

let backgroundGradient = LinearGradient(
    colors: [Color.init(red: 245/255, green: 179/255, blue: 66/255), Color.init(red: 245/255, green: 164/255, blue: 66/255)],
    startPoint: .top, endPoint: .bottom)

