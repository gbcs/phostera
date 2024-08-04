/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The mixer to combine video frames and grayscale depth frames.
 */

import AVFoundation
import CoreImage
import CoreServices


class PhotoOutput: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.flashScreen, object: nil) }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            Logger.shared.error("Error capturing photo: \(error)")
        }
    }
    
    private func jpegData(withPixelBuffer pixelBuffer: CVPixelBuffer, attachments: CFDictionary?) -> Data? {
        let ciContext = CIContext()
        let renderedCIImage = CIImage(cvImageBuffer: pixelBuffer)
        guard let renderedCGImage = ciContext.createCGImage(renderedCIImage, from: renderedCIImage.extent) else {
            Logger.shared.error("Failed to create CGImage")
            return nil
        }
        
        guard let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
                Logger.shared.error("Create CFData error!")
            return nil
        }
        
        guard let cgImageDestination = CGImageDestinationCreateWithData(data, UTType.jpeg as! CFString , 1, nil) else {
            Logger.shared.error("Create CGImageDestination error!")
            return nil
        }
        
        CGImageDestinationAddImage(cgImageDestination, renderedCGImage, attachments)
        if CGImageDestinationFinalize(cgImageDestination) {
            return data as Data
        }
        Logger.shared.error("Finalizing CGImageDestination error!")
        return nil
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let photoPixelBuffer = photo.pixelBuffer else {
            Logger.shared.error("Error occurred while capturing photo: Missing pixel buffer (\(String(describing: error)))")
            return
        }
        
        var photoFormatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: photoPixelBuffer,
                                                     formatDescriptionOut: &photoFormatDescription)
        
        CamTool.shared.getProcessingQueue().async {
            let finalPixelBuffer = photoPixelBuffer
          
            let metadataAttachments: CFDictionary = photo.metadata as CFDictionary
            guard let jpegData = self.jpegData(withPixelBuffer: finalPixelBuffer, attachments: metadataAttachments) else {
                Logger.shared.error("Unable to create JPEG photo")
                return
            }
            
            var outputURL:URL?
            
            let filename = NSUUID().uuidString.appending(".jpg")
            if let take = CameraTakeService.shared.getCurrentTake() {
                outputURL = URL(string: take.localTakeDirectory)?.appendingPathComponent(filename)
            }
            
            guard let outputURL else {
                Logger.shared.error("Unable to create photo url")
                return
            }
           
            do {
                try jpegData.write(to: outputURL)
            } catch {
                Logger.shared.error("Unable to save jpg: \(outputURL)")
            }
            
            if !LibraryController.makeThumbnailFor(url: outputURL) {
                Logger.shared.error("Unable to make thumbnail for jpg: \(outputURL)")
            } else {
                Logger.shared.info("Photo: \(outputURL)")
            }
        }
    }


    func takePicture(depthData:Bool) {
        CamTool.shared.getSessionQueue().async {
            let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
            if depthData && CamTool.shared.getPhotoOutput().isDepthDataDeliverySupported {
                photoSettings.isDepthDataDeliveryEnabled = true
                photoSettings.embedsDepthDataInPhoto = false
            } else {
                photoSettings.isDepthDataDeliveryEnabled = depthData
            }
            
            CamTool.shared.getPhotoOutput().capturePhoto(with: photoSettings, delegate: self)
        }
    }
}
