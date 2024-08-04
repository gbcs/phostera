//
//  SessionKeyEncryptorDecryptor.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/26/23.
//

import Foundation
import CryptoKit
import Security

public enum CryptoError: Error {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case signingFailed
    case verificationFailed
    case keyRetrievalFailed
    case fileHandlingError
}

public class SessionKeyEncryptor {
    public static var shared = SessionKeyEncryptor()
    
    private var localKeyAgreementPrivateKey: P256.KeyAgreement.PrivateKey!
    
    private var localPrivateKey: P256.Signing.PrivateKey!
    private var localPublicKey: P256.Signing.PublicKey!
    
    public func getKeys() -> (P256.Signing.PublicKey, P256.Signing.PrivateKey) {
        return (localPublicKey, localPrivateKey)
    }
    
    public func getAgreementPublicKey() -> (P256.KeyAgreement.PublicKey) {
        return  localKeyAgreementPrivateKey.publicKey
    }
    
    public init() {
        if let keys = loadKeys() {
            self.localPrivateKey = keys.privateKey
            self.localPublicKey = keys.publicKey
        } else {
            try? generateKeys()
        }
        localKeyAgreementPrivateKey = try? P256.KeyAgreement.PrivateKey(rawRepresentation: localPrivateKey.rawRepresentation)
    }
    
    private func generateKeys() throws {
        do {
            localPrivateKey = P256.Signing.PrivateKey()
            localPublicKey = localPrivateKey.publicKey
            
            try saveKeys()
        } catch {
            throw CryptoError.keyGenerationFailed
        }
    }
    
    private func saveKeys() throws {
        let fileURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("session.keys")
        
        do {
            let keyData = localPrivateKey.rawRepresentation
            try keyData.write(to: fileURL)
        } catch {
            throw CryptoError.fileHandlingError
        }
    }
    
    private func loadKeys() -> (privateKey: P256.Signing.PrivateKey, publicKey: P256.Signing.PublicKey)? {
        do {
            let fileURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("session.keys")
            
            let keyData = try Data(contentsOf: fileURL)
            if let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
                let publicKey = privateKey.publicKey
                return (privateKey, publicKey)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    public func encryptAndSign(remotePublicKey: P256.KeyAgreement.PublicKey, message: Data) throws -> (cipherText: Data, signature: Data) {
        do {
            let sharedSecret = try localKeyAgreementPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                                                    salt: Data(),
                                                                    sharedInfo: Data(),
                                                                    outputByteCount: 32)
            let sealedBox = try ChaChaPoly.seal(message, using: symmetricKey)
            let ecdsaSignature = try localPrivateKey.signature(for: sealedBox.combined)
            let signatureData = ecdsaSignature.rawRepresentation
            return (sealedBox.combined, signatureData)
        } catch {
            throw CryptoError.encryptionFailed
        }
    }
    
    public func decryptAndVerify(remoteSigningPublicKey: P256.Signing.PublicKey, remoteAgreementPublicKey: P256.KeyAgreement.PublicKey, cipherText: Data, signature: Data) throws -> Data {
        do {
            let sharedSecret = try localKeyAgreementPrivateKey.sharedSecretFromKeyAgreement(with: remoteAgreementPublicKey)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                                                    salt: Data(),
                                                                    sharedInfo: Data(),
                                                                    outputByteCount: 32)
            let sealedBox = try ChaChaPoly.SealedBox(combined: cipherText)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: symmetricKey)
            
           // let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            
//            if !remoteSigningPublicKey.isValidSignature(ecdsaSignature, for: sealedBox.combined) {
//                throw CryptoError.verificationFailed
//            }
            
            return decryptedData
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}

