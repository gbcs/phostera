//
//  MainControlView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/12/23.
//

import UIKit
import SwiftUI
import Combine
import PhosteraShared

class MainControlView: UIView {
    @State var path:[LibraryRoute] = [LibraryRoute]()
    @State var itemList:[FootageFileItem] = [FootageFileItem]()
    
    private var recording: Bool = false
    
    private var recordButtonImageView: UIImageView
    private var libraryButtonImageView: UIImageView
    private var settingsButtonImageView: UIImageView
    private var subRecordingState:AnyCancellable?
    
    private var frames:[String:CGRect] = [
        "record" :   CGRectMake(  0, 0, 50, 50)//,
//        "library" :  CGRectMake(   55, 10, 30, 30),
//        "settings" : CGRectMake(   10, 10, 30, 30),
    ]
    
    init(frame:CGRect, zoomEnabled:Bool) {
        precondition(Thread.isMainThread)
        self.recordButtonImageView = UIImageView(image: UIImage(systemName: "record.circle"))
        self.libraryButtonImageView = UIImageView(image: UIImage(systemName: "list.and.film"))
        self.settingsButtonImageView = UIImageView(image: UIImage(systemName: "gear"))
        
        self.recordButtonImageView.frame = frames["record"] ?? CGRectZero
        self.libraryButtonImageView.frame = frames["library"] ?? CGRectZero
        self.settingsButtonImageView.frame = frames["settings"] ?? CGRectZero
        
        self.recordButtonImageView.tintColor = UIColor.white
        self.libraryButtonImageView.tintColor = UIColor.white
        self.settingsButtonImageView.tintColor = UIColor.white
       
        self.recordButtonImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .medium)
        self.libraryButtonImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .medium)
        self.settingsButtonImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .medium)

        super.init(frame: frame)

        self.backgroundColor = UIColor.clear
        self.loadButtons()
    }
    
    func setup() {
        precondition(Thread.isMainThread)
        subRecordingState = PubCentral.shared.pubRecordingState?.receive(on: DispatchQueue.main).sink { value in
            self.recording = value
            if self.recording {
                self.recordButtonImageView.image = UIImage(systemName: "record.circle.fill")
                self.recordButtonImageView.tintColor = UIColor.systemRed
               
            } else {
                self.recordButtonImageView.image = UIImage(systemName: "record.circle")
                self.recordButtonImageView.tintColor = UIColor.white
            }
            UIView.animate(withDuration: 0.5) {
                self.settingsButtonImageView.alpha = self.recording ? 0.0 : 1.0
                self.libraryButtonImageView.alpha = self.recording ? 0.0 : 1.0
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("We aren't using storyboards")
    }
    
    @objc private func userTappedRecord(_ sender: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if (self.recording) {
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
        } else {
            if CamTool.shared.getCameraTech() != .photo {
                self.recordButtonImageView.isUserInteractionEnabled = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
                    self.recordButtonImageView.isUserInteractionEnabled = true
                })
            }
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.beginRecording, object: nil) }
        }
    }

    @objc private func userTappedLibrary(_ sender: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.UtilityPages.library, object: nil) }
    }
    
    @objc private func userTappedSettings(_ sender: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.UtilityPages.settings, object: nil) }
    }
    
    func recordingStatus(isRecording:Bool) {
        precondition(Thread.isMainThread)
        if self.recording != isRecording {
            self.recording = isRecording
            if isRecording {
                self.libraryButtonImageView.isUserInteractionEnabled = false
                self.settingsButtonImageView.isUserInteractionEnabled = false
                self.settingsButtonImageView.alpha = 0.7
                self.libraryButtonImageView.alpha = 0.7
            } else {
                self.settingsButtonImageView.alpha = 1.0
                self.libraryButtonImageView.alpha = 1.0
                self.libraryButtonImageView.isUserInteractionEnabled = true
                self.settingsButtonImageView.isUserInteractionEnabled = true
            }
          
            UIView.animate(withDuration: 0.5) {
                if self.recording {
                    self.recordButtonImageView.tintColor = UIColor.red
                } else {
                    self.recordButtonImageView.tintColor = UIColor.white
                }
            } completion: { _ in  }
        }
    }

    private func loadButtons() {
        precondition(Thread.isMainThread)
        let tapRecord = UITapGestureRecognizer()
        tapRecord.addTarget(self, action: #selector(userTappedRecord(_:)))
        self.recordButtonImageView.isUserInteractionEnabled = true
        self.recordButtonImageView.addGestureRecognizer(tapRecord)
        
        let tapLibrary = UITapGestureRecognizer()
        tapLibrary.addTarget(self, action: #selector(userTappedLibrary(_:)))
        self.libraryButtonImageView.isUserInteractionEnabled = true
        self.libraryButtonImageView.addGestureRecognizer(tapLibrary)
        
        let tapSettings = UITapGestureRecognizer()
        tapSettings.addTarget(self, action: #selector(userTappedSettings(_:)))
        self.settingsButtonImageView.isUserInteractionEnabled = true
        self.settingsButtonImageView.addGestureRecognizer(tapSettings)
        
        self.addSubview(recordButtonImageView)
        self.addSubview(libraryButtonImageView)
        self.addSubview(settingsButtonImageView)
        
    }
}
