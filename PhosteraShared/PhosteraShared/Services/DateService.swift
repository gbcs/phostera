//
//  DateService.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/17/23.
//

import Foundation

public class DateService {
    public static func filenameDateFormat(locale: Locale = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale

        let dateFormatTemplate = DateFormatter.dateFormat(fromTemplate: "yyyyMMdd HHmmss", options: 0, locale: locale) ?? "yyyyMMdd_HHmmss"

        var customFormat = dateFormatTemplate.replacingOccurrences(of: ":", with: "_")
        customFormat = customFormat.replacingOccurrences(of: "/", with: "_")
        customFormat = customFormat.replacingOccurrences(of: ",", with: "_")
        customFormat = customFormat.replacingOccurrences(of: " ", with: "")
        return customFormat
    }
    
    public static var shared = DateService()
    private var hourMinDateFormatter = DateFormatter()
    private var hourMinSecDateFormatter = DateFormatter()
    private var componentFormatter = DateComponentsFormatter()
    
    private var dateTimeStampFormatter = DateFormatter()
    private var filenameDateTimeFormatter = DateFormatter()
    
    public init() {
        hourMinDateFormatter.dateFormat = "HH:mm"
        hourMinDateFormatter.dateFormat = "HH:mm:ss"
   
        componentFormatter.allowedUnits = [.hour, .minute, .second]
        componentFormatter.zeroFormattingBehavior = [.pad]
        
        dateTimeStampFormatter.dateStyle = .short
        dateTimeStampFormatter.timeStyle = .short
        
        filenameDateTimeFormatter.dateStyle = .short
        filenameDateTimeFormatter.timeStyle = .short
        filenameDateTimeFormatter.dateFormat = DateService.filenameDateFormat()
    }
    
    public func filenameForCurrentDateTime() -> String {
        return filenameDateTimeFormatter.string(from: .now)
    }
    
    public func dateTimeStamp(date:Date) -> String {
        return dateTimeStampFormatter.string(from: date)
    }
    
    public func hourMinFrom(date:Date) -> String {
        return hourMinDateFormatter.string(from: date)
    }
    
    public func hourMinSecFrom(date:Date) -> String {
        return hourMinSecDateFormatter.string(from: date)
    }
    
    public func componentStringFrom(duration:TimeInterval) -> String {
        return componentFormatter.string(from: duration) ?? "--:--"
    }
}
