//
//  NewUserRequest.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/9/23.
//

import UIKit
import PhosteraShared

let newUserRequestViewTag = 42

class NewUserRequestView: UIView, UITextFieldDelegate, UITextViewDelegate {
    private let messageHeader: UILabel = UILabel(title: "New Director/Streamer")
    private let directorNameTitle: UILabel = UILabel(title: "Name:")
    private let directorNameValue: UILabel = UILabel()
    
    private let directorIDTitle: UILabel = UILabel(title: "ID:")
    private let directorIDValue: UILabel = UILabel()
    
    private  let messageValue: UILabel = UILabel()
    
    private let allowButton: UIButton = UIButton(configuration: .borderedProminent())
    private let denyButton: UIButton = UIButton(configuration: .borderedProminent())
    
    private var director:DirectorModel
    
    override func layoutSubviews() {

        messageHeader.frame = CGRectMake(2, 2, 286, 30)
          
        directorNameTitle.frame = CGRectMake(10, 35, 70, 25)
        directorNameValue.frame = CGRectMake(75, 35, 225, 25)
        
        directorIDTitle.frame = CGRectMake(10, 70, 70, 25)
        directorIDValue.frame = CGRectMake(75, 70, 225, 25)
        
        messageValue.frame = CGRectMake(10, 100, 280, 150)
        
        allowButton.frame = CGRectMake(10, 240, 120, 50)
        denyButton.frame = CGRectMake(170, 240, 120, 50)
        
//        [directorNameTitle, directorNameValue, directorIDTitle, directorIDValue,
//     messageValue, allowButton, denyButton].forEach {
//               $0.translatesAutoresizingMaskIntoConstraints = false
//           }
  
        super.layoutSubviews()
    }
    
    
    
    init(frame: CGRect, directorIn:DirectorModel, message: String) {
        precondition(Thread.isMainThread)
        director = directorIn
        super.init(frame: frame)
        tag = newUserRequestViewTag
        directorNameValue.text = director.title
        directorIDValue.text = director.uuid
        messageValue.text = message
        
        addSubviews()
        
        backgroundColor = UIColor.white
        
        allowButton.setTitle("Allow", for: .normal)
        denyButton.setTitle("Block", for: .normal)
        
        allowButton.setTitleColor(.white, for: .normal)
        denyButton.setTitleColor(.white, for: .normal)

        messageValue.lineBreakMode = .byWordWrapping
        messageValue.numberOfLines = 0

        [directorNameTitle, directorNameValue, directorIDTitle, directorIDValue,
         messageValue, messageHeader].forEach {
            $0.textColor = UIColor.black
        }
        
        allowButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            precondition(Thread.isMainThread)
            DirectorService.shared.allowConnection(director: director)
            
        }), for: .touchUpInside)
        
        denyButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            precondition(Thread.isMainThread)
            DirectorService.shared.denyConnection(director: director)
        }), for: .touchUpInside)
        
        
        messageHeader.textAlignment = .center
        messageHeader.font = .preferredFont(forTextStyle: .headline)
        
        directorNameTitle.textAlignment = .left
        directorIDTitle.textAlignment = .left
        
        directorNameValue.textAlignment = .left
        directorIDValue.textAlignment = .left
        
        messageValue.textAlignment = .center
        messageValue.numberOfLines = 0
        messageValue.lineBreakMode = .byWordWrapping
        
        Logger.shared.info("New User request view init")
    }
    
    private func addSubviews() {
        precondition(Thread.isMainThread)
        [directorNameTitle, directorNameValue, directorIDTitle, directorIDValue,
          messageValue, allowButton, denyButton, messageHeader].forEach {
            addSubview($0)
        }
    }
    
    required init?(coder: NSCoder) {
        precondition(Thread.isMainThread)
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Logger.shared.info("New User request view deinit")
    }
    
}

extension UILabel {
    convenience init(title: String) {
        precondition(Thread.isMainThread)
        self.init()
        text = title
    }
}

extension UIButton {
    convenience init(title: String) {
        precondition(Thread.isMainThread)
        self.init()
        setTitle(title, for: .normal)
    }
}

