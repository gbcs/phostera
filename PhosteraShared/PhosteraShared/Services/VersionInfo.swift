//
//  VersionInfo.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 11/3/23.
//

import Foundation

public class VersionInfo {
    public static var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    public static var productVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
}
