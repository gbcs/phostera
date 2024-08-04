
import Swift
import SelfSignedCert
import Foundation
import OSLog

enum ServerKeysErrors: Error {
    case identityCreation
    case emptyPublicKey
    case emptyPublicKeyKeyData
    case createCertKeyData
    case badCertPublicKeyFromUserDefaults
    case badIdentityReconstitution
    case badPrivateKeyReconstitution
    case badCertReconstitution
    case badCert
    case certWriteError
}

struct ServerKeys {
    static func generateKeysForServer() throws {
        if SettingsService.shared.settings.serverUUID.lengthOfBytes(using: .ascii) < 1 {
            //New setup
            let serverId = UUID().uuidString.prefix(8)
            guard let identity = SecIdentity.create(subjectCommonName: "\(serverId).local", subjectEmailAddress: "\(serverId)@local") else {
                Logger.shared.error("Unable to create an identity: \(serverId)")
                throw ServerKeysErrors.identityCreation
            }
            
            let cert: SecCertificate? = identity.certificate
            let pubKey = cert?.publicKey
            let pubKeyData = pubKey?.keyData
            
            guard let empty = pubKeyData?.isEmpty else {
                throw ServerKeysErrors.emptyPublicKey
            }
            
            if empty {
                throw ServerKeysErrors.emptyPublicKeyKeyData
            }
            
            let pubKeyDataOut:Data = Data.init(bytes:pubKeyData!, count:pubKeyData!.count)
            
            SettingsService.shared.settings.serverPublicKey = pubKeyDataOut
            SettingsService.shared.settings.serverUUID = String(serverId)
            SettingsService.shared.save()
            Logger.shared.info("Server Key Created for serverUUID: \(serverId)")
        }
    }
    
    static func keysForServer() throws -> SecIdentity {
        try? ServerKeys.generateKeysForServer()
        
        let serverPublicKey:Data = SettingsService.shared.settings.serverPublicKey
        
        guard let secKey = SecKey.create(withData: serverPublicKey.bytes) else {
            throw ServerKeysErrors.badCertPublicKeyFromUserDefaults
        }
        
        let identity = SecIdentity.find(withPublicKey: secKey)
        
        if (identity == nil) {
            throw ServerKeysErrors.badIdentityReconstitution
        }
 
        return identity! as SecIdentity
    }
}
