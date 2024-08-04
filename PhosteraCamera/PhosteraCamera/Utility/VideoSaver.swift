//
//  VideoSaver.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/18/23.
//

import UIKit

class VideoSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?

    func videoIsCompatibleWithPhotoAlbum(video:String) -> Bool {
        if !video.isEmpty {
            return UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(video)
        }
        return false
    }
    
    func writeToPhotoAlbum(video:String) {
        UISaveVideoAtPathToSavedPhotosAlbum(video, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}
