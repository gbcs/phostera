//
//  GenerateQRCode.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/30/23.
//

import UIKit
import CoreImage

public class QRCode {
    public static func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("Q", forKey: "inputCorrectionLevel")
            
            if let qrCIImage = filter.outputImage {
                let scaleX = 300 / qrCIImage.extent.size.width
                let scaleY = 300 / qrCIImage.extent.size.height
                let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                
                let qrTransformedImage = qrCIImage.transformed(by: transform)
                if let cgImage = CIContext().createCGImage(qrTransformedImage, from: qrTransformedImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }
}
