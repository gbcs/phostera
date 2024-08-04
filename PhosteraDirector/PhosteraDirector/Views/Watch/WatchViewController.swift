//
//  Collection.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/21/23.
//

import UIKit
import Combine
import SwiftUI
import PhosteraShared

extension Notification.Name {
    static let itemInvalidated = Notification.Name("itemInvalidated")
}

class WatchViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var collectionView:UICollectionView!
    let layout = UICollectionViewFlowLayout()
    
    var cancellables:[AnyCancellable] = []
    var showCameraInfo:Bool = false
    
    func updateSize() {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        layout.estimatedItemSize = .zero
        layout.itemSize = CGSize(width: 100, height: 100)
        WatchEntryManager.shared.loadInitialList()
        collectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        
        collectionView.backgroundColor = .black
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.alwaysBounceVertical = true
        collectionView.alwaysBounceHorizontal = true
        collectionView.indicatorStyle = .white
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CollectionCell.self, forCellWithReuseIdentifier: CollectionCell.identifer)
        collectionView.allowsMultipleSelection = false
       
        self.view.addSubview(collectionView)
        NotificationCenter.default.addObserver(self, selector: #selector(handleItemInvalidated(_:)), name: .itemInvalidated, object: nil)
  
        cancellables.append(PubCentral.shared.cameraUpdated.sink() { [weak self] value in
            guard let self else { return }
            layout.invalidateLayout()
        })
        
        cancellables.append(PubCentral.shared.cameraListChanged.sink() { [weak self] value in
            guard let self else { return }
            collectionView.reloadData()
        })
        
        self.cancellables.append(PubCentral.shared.pubEnterBackground.receive(on: DispatchQueue.main).sink { value in
            WatchEntryManager.shared.stopWatching()
            Task {
                await NetworkHandler.shared.cameraFinder.stopBrowsing()
                await NetworkHandler.shared.removeAllCommandConnections()
                await NetworkHandler.shared.removeAllVideoConnections()
                await NetworkHandler.shared.removeAllAudioConnections()
            }
        })
        
        self.cancellables.append(PubCentral.shared.pubWillEnterForeground.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            layout.invalidateLayout()
            collectionView.reloadData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                Task {
                    await NetworkHandler.shared.cameraFinder.startBrowsing()
                }
                WatchEntryManager.shared.startWatching()
            })
        })
        
        self.cancellables.append(PubCentral.shared.toggleCameraInfoView.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            showCameraInfo = !showCameraInfo
            layout.invalidateLayout()
        })
    }
    
    
    func indexPath(for uuid:String) -> IndexPath? {
        let entries = WatchEntryManager.shared.getAvailableCameras()
        
        let count = entries.count
        
        for x in 0..<count {
            if entries[x].uuid == uuid { return IndexPath(row: x, section: 0) }
        }
        
        return nil
    }
    
    @objc private func watch() {
        
    }
    
    @objc func handleItemInvalidated(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuid = userInfo["uuid"] as? String,
           let size = userInfo["size"] as? CGSize,
           let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            // if let indexPath = indexPath(for: uuid) {
            for model in WatchEntryManager.shared.getAvailableCameras() {
                if model.uuid == uuid {
                    model.size = size
                    break
                }
            }
            //let context = UICollectionViewFlowLayoutInvalidationContext()
            //context.invalidateItems(at: [indexPath])
            //layout.invalidateLayout(with: context)
            layout.invalidateLayout() //When an item changes size, they all need repositioning
            // }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let collectionView else { return }
        
        if CameraController.hasPermission() {
            if CameraManager.shared.getCamera(uuid: lightMeterUUID) == nil {
                _ = CameraManager.shared.addCamera(camera: CameraModel(uuid: lightMeterUUID, name: "Light Meter", model: "iPad", blocked: false))
                _ = CameraManager.shared.availableUUIDs.insert(lightMeterUUID)
            }
            
            CameraManager.shared.setUUIDStatus(uuid: lightMeterUUID, online: true)
        }
        
        collectionView.reloadData()
        if collectionView.numberOfItems(inSection: 0) > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        }
    }
    
    func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let n = WatchEntryManager.shared.getAvailableCameras().count
        return n
    }
    
    func collectionView(  _ collectionView: UICollectionView,  layout collectionViewLayout: UICollectionViewLayout,  sizeForItemAt indexPath: IndexPath  ) -> CGSize {
        guard let entry = entry(for: indexPath) else { preconditionFailure("Failed to load collection view cell data") }
        return entry.size
    }
    
    func entry(for indexPath:IndexPath) -> WatchEntryModel? {
        return WatchEntryManager.shared.getAvailableCameras()[indexPath.row]
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let entry = entry(for: indexPath) else { preconditionFailure("Failed to load collection view cell data") }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionCell.identifer, for: indexPath) as? CollectionCell
        else { preconditionFailure("Failed to load collection view cell") }

        cell.update(uuid:entry.uuid)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? CollectionCell {
            let uuid = cell.getUUID()
            WatchEntryManager.shared.selectedUUID = uuid
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.selectedChanged, object: nil) }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let _ = collectionView.cellForItem(at: indexPath) as? CollectionCell {
            if let _ = WatchEntryManager.shared.selectedUUID  {
                WatchEntryManager.shared.selectedUUID = nil
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.selectedChanged, object: nil) }
            }
        }
    }
    
    internal func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let cell = collectionView.cellForItem(at: indexPath) as? CollectionCell {
            if cell.getUUID() == lightMeterUUID {
                return false //Light Meter; not selectable
            }
        }
        return true
    }
}

