//
//  ExternalMonitorViewController.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/4/23.
//

import UIKit

class ExternalMonitorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gray

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Called when the view is about to made visible. Default does nothing
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Called when the view has been fully transitioned onto the screen. Default does nothing
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Called when the view is about to be removed from a view hierarchy and transitioned to hidden. Default does nothing
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Called after the view was dismissed, covered or otherwise hidden. Default does nothing
    }
    
    // ... other override methods or custom methods ...
}
