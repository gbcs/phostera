//
//  ImageResizer.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/3/23.
//

import UIKit

class ImageResizer {
    static func resizeImage(image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 1920, height: 1080)
        let imageSize = image.size
        
        var newSize: CGSize
        var croppingRect = CGRect.zero
        
        if imageSize.width < targetSize.width || imageSize.height < targetSize.height {
            let widthRatio  = targetSize.width  / imageSize.width
            let heightRatio = targetSize.height / imageSize.height
            let scalingFactor = max(widthRatio, heightRatio)
            
            newSize = CGSize(width: imageSize.width * scalingFactor, height: imageSize.height * scalingFactor)
        } else {
            let widthRatio  = targetSize.width  / imageSize.width
            let heightRatio = targetSize.height / imageSize.height
            let scalingFactor = min(widthRatio, heightRatio)
            
            newSize = CGSize(width: imageSize.width * scalingFactor, height: imageSize.height * scalingFactor)
            croppingRect.size = targetSize
            croppingRect.origin.x = (newSize.width - targetSize.width) / 2
            croppingRect.origin.y = (newSize.height - targetSize.height) / 2
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if croppingRect != CGRect.zero {
            let croppedImage = ImageResizer.croppedImageFrom(image: resizedImage!, croppingRect: croppingRect)
            return croppedImage
        }
        
        return resizedImage!
    }
    
    static func croppedImageFrom(image: UIImage, croppingRect: CGRect) -> UIImage {
        let imageRef = image.cgImage!.cropping(to: croppingRect)
        let croppedImage = UIImage(cgImage: imageRef!, scale: image.scale, orientation: image.imageOrientation)
        return croppedImage
    }
    
}
