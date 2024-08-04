//
//  LocationController.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/5/23.
//

import Foundation
import CoreLocation

//Wrangle the location service on device state changes. Stay down if user doesn't want location metadata.
public class LocationController: NSObject, CLLocationManagerDelegate {
    static var shared = LocationController()
    let locationManager:CLLocationManager
    
    override init () {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
    }
    
    func hasPermissionDenied() -> Bool {
        return locationManager.authorizationStatus == .denied
    }
    
    func hasPermissionRestricted() -> Bool {
        return locationManager.authorizationStatus == .restricted
    }
    
    func hasPermission() -> Bool {
        return (locationManager.authorizationStatus == .authorizedWhenInUse) || (locationManager.authorizationStatus == .authorizedAlways)
    }
    
    func requestPermission() {
        if (!(hasPermission()) && (!hasPermissionDenied())) {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .locationAccessChanged, object: nil) }
    }
    
    func isRunning() -> Bool {
        return false
    }
    
    func locationString() -> String? {
        // ISO 6709 Standard format: ±DD.DDDD±DDD.DDDD/
        if !isRunning() {
            return nil
        }
        
        if let l = locationManager.location {
            return String(format: "%+.4f%+.4f/",
                          l.coordinate.latitude,
                          l.coordinate.longitude)
        }
        
        return nil
    }

// We dont' want to continually update location. Once at recording start is good.
//    func start() {
//        locationManager.startUpdatingLocation()
//    }
//    
//    func stop()  {
//        locationManager.stopUpdatingLocation()
//    }
    
    func getCurrentCoordinates() {
        
    }
    
    func createDrivingDirectionsToEvent() {
        
    }
}
