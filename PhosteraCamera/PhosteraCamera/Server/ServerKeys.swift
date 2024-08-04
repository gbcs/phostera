
import Swift
import SelfSignedCert
import Foundation


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
    static func startServer() {
        Logger.shared.info("Starting Servers")
        Task {
            await CommandServer.shared.start()
            await VideoStreamServer.shared.start()
            await AudioStreamServer.shared.start()
        }
    }
    
    static func stopServer() {
        Logger.shared.info("Stopping Server")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.25, execute: {
            Task {
                await CommandServer.shared.stop()
                await VideoStreamServer.shared.stop()
                await AudioStreamServer.shared.stop()
            }
        })
    }
   
    static func generateKeyForServer() throws {
        if SettingsService.shared.settings.serverUUID.lengthOfBytes(using: .utf8) < 1 {
            //New setup
            let serverId = UUID().uuidString.prefix(8)
            guard let identity = SecIdentity.create(subjectCommonName: "\(serverId).local", subjectEmailAddress: "\(serverId)@local") else {
                Logger.shared.error("Unable to create an identity")
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
            Logger.shared.info("Server Keys Created for serverUUID: \(serverId)")
        } else {
            Logger.shared.info("Server UUID found: \(SettingsService.shared.settings.serverUUID)")
        }
    }
    
    static func keysForServer() throws -> SecIdentity {
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
