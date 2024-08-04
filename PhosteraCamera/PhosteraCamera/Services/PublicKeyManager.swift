//
//  PublicKeyManager.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/25/23.
//

import Foundation
import CommonCrypto
import Security

class PublicKeyManager {
    static var shared = PublicKeyManager()
    
    func deletePublicKey(from trust: Data) {
        if let hashString = getHash(from: trust) {
            let url = getFilePath(for: hashString)
            do {
                try FileManager.default.removeItem(atPath: url.path)
            } catch {
                Logger.shared.error("Failed to delete: \(error)")
            }
        }
    }
    
    func savePublicKey(from trust: Data) -> String? {
        if let hashString = getHash(from: trust) {
            let url = getFilePath(for: hashString)
            do {
                try trust.write(to: url)
                return hashString
            } catch {
                Logger.shared.error("Failed to write: \(error)")
            }
        }
        return nil
    }
    
    func comparePublicKey(from trust: Data) -> Bool {
        if let hashString = getHash(from: trust) {
            let url = getFilePath(for: hashString)
            do {
                let data = try Data(contentsOf: url)
                if trust.bytes == data.bytes {
                    return true
                }
            } catch {
                Logger.shared.error("Failed to read: \(error)")
            }
        }
        return false
    }
    
    private func publicKeyStorageURL() -> URL {
        let appSupport = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            Logger.shared.error("Unable to create app support directory.")
        }
        let keyURL = appSupport.appendingPathComponent("publicKeys")
        if !FileManager.default.fileExists(atPath: keyURL.path) {
            do {
                try FileManager.default.createDirectory(at: keyURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create keyURL support directory.\(error)")
            }
        }
        return keyURL
    }
    
    private func getFilePath(for hashString: String) -> URL {
        return publicKeyStorageURL().appendingPathComponent(hashString, conformingTo: .data)
    }
    
    private func getHash(from trust: Data) -> String? {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        trust.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(trust.count), &hash)
        }
        
        let hashData = Data(hash)
        return hashData.map { String(format: "%02x", $0) }.joined()
    }
}

