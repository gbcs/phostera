//
//  ImageResizer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/4/23.
//

import UIKit

class ImageResizer {
    static func resizeImage(image: UIImage) -> UIImage {
        Logger.shared.info("ResizeIn:\(image.size.width)x\(image.size.height)")
        let targetSize = CGSize(width: 1920, height: 1080)
        let imageSize = image.size

        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scalingFactor = max(widthRatio, heightRatio)

        let newSize = CGSize(width: imageSize.width * scalingFactor, height: imageSize.height * scalingFactor)
        let x = (newSize.width - targetSize.width) / 2
        let y = (newSize.height - targetSize.height) / 2

        let croppingRect = CGRect(x: x, y: y, width: targetSize.width, height: targetSize.height)

        UIGraphicsBeginImageContextWithOptions(croppingRect.size, false, 0.0)
        image.draw(in: CGRect(x: -x, y: -y, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        Logger.shared.info("ResizeOut:\(resizedImage!.size.width)x\(resizedImage!.size.height)")

        return resizedImage!
    }

    static func croppedImageFrom(image: UIImage, croppingRect: CGRect) -> UIImage {
        let imageRef = image.cgImage!.cropping(to: croppingRect)
        let croppedImage = UIImage(cgImage: imageRef!, scale: image.scale, orientation: image.imageOrientation)
        return croppedImage
    }
    
}
