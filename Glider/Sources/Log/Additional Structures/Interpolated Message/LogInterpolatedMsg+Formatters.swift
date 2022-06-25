//
//  Glider
//  Fast, Lightweight yet powerful logging system for Swift.
//
//  Created by Daniele Margutti
//  Email: <hello@danielemargutti.com>
//  Web: <http://www.danielemargutti.com>
//
//  Copyright ©2022 Daniele Margutti. All rights reserved.
//  Licensed under MIT License.
//

import Foundation
import CoreGraphics

// MARK: - Formats

extension String {
    
    /// Apply privacy scope.
    ///
    /// - Parameter privacy: privacy scope.
    /// - Returns: String
    internal func privacy(_ privacy: LogPrivacy?) -> String {
        guard let privacy = privacy else {
            return self
        }

       #if DEBUG
        if GliderSDK.shared.disablePrivacyRedaction {
            return String(describing: self)
        }
        #endif
        
        switch privacy {
        case .public:
            return String(describing: self)
        case .private(mask: .hash):
            return "\(String(describing: self).hash)"
        case .private(mask: .partiallyHide):
            var hiddenString = self
            let charsToHide = Int(Double(hiddenString.count) * 0.35)
            let endIndex = index(hiddenString.startIndex, offsetBy: charsToHide)
            hiddenString.replaceSubrange(...endIndex, with: String(repeating: "*", count: charsToHide))
            return hiddenString
        default:
            return LogPrivacy.redacted
        }
    }
    
}

extension Bool {
    
    internal func format(_ format: LogBoolFormatting?) -> String {
        guard let format = format else {
            return String(describing: self)
        }

        switch format {
        case .answer:
            return (self ? "yes": "no")
        case .truth:
            return (self ? "true": "false")
        case .numeric:
            return (self ? "1" : "0")
        }
    }
    
}

extension Double {
    
    internal static func format(value: NSNumber, _ format: LogDoubleFormatting?) -> String {
        guard let format = format else {
            return String(describing: self)
        }
        
        switch format {
        case .fixed(let precision, let explicitPositiveSign):
            return  String(format: "\(explicitPositiveSign ? "+" : "")%.0\(precision)f", value)
            
        case .formatter(let formatter):
            return formatter.string(for: value) ?? ""
            
        case .measure(let unit, let options, let style):
            let formatter = MeasurementFormatter()
            formatter.unitOptions = options
            formatter.unitStyle = style
            formatter.locale = GliderSDK.shared.locale
            return formatter.string(from: .init(value: value.doubleValue, unit: unit))
            
        case .bytes(let style):
            let formatter = ByteCountFormatter()
            formatter.countStyle = style
            return formatter.string(from: .init(value: value.doubleValue, unit: .bytes))
            
        }
    }
    
}

extension Date {
    
    internal func format(_ format: LogDateFormatting?) -> String {
        guard let format = format else {
            return String(describing: self)
        }
        
        switch format {
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: self)
            
        case .custom(let format):
            let formatter = DateFormatter()
            formatter.locale = GliderSDK.shared.locale
            formatter.dateFormat = format
            return formatter.string(from: self)
            
        }
    }
    
}

extension CGSize {
    
    internal func format(_ format: LogCGModelsFormatting?) -> String {
        guard let format = format else {
            return String(describing: self)
        }
        
        switch format {
        case .withPrecision(let precision):
            return "(\(String(format: "%.\(precision)f", width)), \(String(format: "%.\(precision)f", height)))"
        case .natural:
            return "(w:\(String(format: "%.2f", width)), h:\(String(format: "%.2f", height)))"

        }
    }
    
}

extension CGFloat {
    
    internal func format(_ format: LogCGModelsFormatting?) -> String {
        guard let format = format else {
            return String(describing: self)
        }
        
        switch format {
        case .withPrecision(let precision):
            return "\(String(format: "%.\(precision)f"))"
        case .natural:
            return "\(String(format: "%.2f"))"

        }
    }
    
}