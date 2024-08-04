//
//  LogToRecConverter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/31/23.
//

import CoreImage

class ColorConverter {
    private let colorCubeFilter: CIFilter
    
    init?(cubeFileURL: URL) {
        // Load the LUT data from the .cube file
        guard let lutData = try? Data(contentsOf: cubeFileURL),
              let colorCubeFilter = CIFilter(name: "CIColorCube") else {
            return nil
        }
        
        let cubeDimension: Float = 65
        let cubeData = lutData.withUnsafeBytes { Data(bytes: $0.baseAddress!, count: lutData.count) }
        
//        let channels = 3
//        let bytesPerChannel = 2
       // let cubeDimension = pow(Double(lutData.bytes.count) / Double(channels * bytesPerChannel), 1.0/3.0)

        
        
        colorCubeFilter.setValue(cubeDimension, forKey: "inputCubeDimension")
        colorCubeFilter.setValue(cubeData, forKey: "inputCubeData")
        
        self.colorCubeFilter = colorCubeFilter
    }
    
    func convert(image: CIImage) -> CIImage? {
        colorCubeFilter.setValue(image, forKey: kCIInputImageKey)
        return colorCubeFilter.outputImage
    }
}
