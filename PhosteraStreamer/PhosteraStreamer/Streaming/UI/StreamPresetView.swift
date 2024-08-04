//
//  StreamPresetView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/6/23.
//

import UIKit

class StreamPresetView: UIView {
    let buttonStack = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButtons()
    }
    
    @objc func presetButtonTapped(_ sender: UIButton) {
        NotificationCenter.default.post(name: Notification.Name.presetChosen, object: nil, userInfo: ["index": sender.tag - 1])
    }
    
    @objc func resetButtonTapped() {
        NotificationCenter.default.post(name: Notification.Name.presetReset, object: nil, userInfo: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let superview {
            let isPortrait = superview.bounds.height > superview.bounds.width
            buttonStack.axis = isPortrait ? .horizontal : .vertical
            
            let buttonWidth: CGFloat = 44
            let buttonHeight: CGFloat = 44
            let totalButtonHeight = buttonHeight * CGFloat(buttonStack.arrangedSubviews.count) + buttonStack.spacing * CGFloat(buttonStack.arrangedSubviews.count - 1)
            
            if isPortrait {
                let x: CGFloat = 0
                buttonStack.frame = CGRect(x: x, y: 0, width: superview.bounds.width, height: buttonHeight)
            } else {
                let y = (self.frame.size.height - totalButtonHeight) / 2
                buttonStack.frame = CGRect(x: 0, y: y, width: buttonWidth, height: totalButtonHeight)
            }
        }
    }
    
    func selectButton() {
        Task {
            let project = await ProjectService.shared.currentProject()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for button in buttonStack.arrangedSubviews {
                    if button.tag - 1 == project.currentPreset {
                        button.backgroundColor = .blue
                    } else {
                        button.backgroundColor = .clear
                    }
                }
            }
        }
    }
    
    func setupButtons() {
        buttonStack.axis = .vertical
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10
        addSubview(buttonStack)
     
        for i in 1...5 {
            let button = UIButton()
            button.setTitle("\(i)", for: .normal)
            button.tag = i
            button.addTarget(self, action: #selector(presetButtonTapped(_:)), for: .touchUpInside)
            buttonStack.addArrangedSubview(button)
        }
        
        let saveButton = UIButton()
        saveButton.setImage(UIImage(systemName: "arrow.3.trianglepath"), for: .normal)
        saveButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(saveButton)
        selectButton()
    }
}
