//
//  ExternalStorageSaver.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/23/23.
//

import UIKit

class ExternalStorageSaver: NSObject {
    var successHandler: (() -> Void)?
    var failHandler: (() -> Void)?

    func save(takeUUID:String) {
        Task {
            let answer = LibraryController.copyItemToExternalStorage(takeUUID: takeUUID)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                saveCompleted(finished: answer)
            }
        }
    }
    
    @objc func saveCompleted(finished:Bool) {
        if finished {
            successHandler?()
        } else {
            failHandler?()
        }
    }
}
