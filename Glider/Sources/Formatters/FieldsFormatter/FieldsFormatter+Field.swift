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
import SwiftUI
import Network

extension FieldsFormatter {
    
    /// Represent a single elemnt of the formatter strings to produce.
    /// Each `Field` represent a log attribute to print along with their options and styles.
    public struct Field {
        public typealias Configure = ((inout Field) -> Void)
    
        // MARK: - Public Properties
        
        /// Represented field key.
        public let field: FieldIdentifier
        
        /// Optionally truncate the output string.
        /// By default is set to `nil` which means no truncation is applied.
        public var truncate: String.TruncationStyle?
        
        /// Pad to the specified width and style, `nil` to avoid padding.
        public var padding: String.PaddingStyle?
        
        /// Optional string transform functions, evaluated in prder.
        public var transforms: [String.Transform]?
        
        /// Readable label for field.
        ///
        /// NOTE:
        /// Some formatters (like the `JSONFormatter`= uses this value to print the field's readable label.
        public var label: String?
        
        /// Colors to apply to the string.
        ///
        /// NOTE:
        /// It works only for certain formatters (like `XCodeFormatter` and `TerminalFormatter` where
        /// colorization is supported. Some formatters may ignore this value.
        public var colors: [FieldsFormatterColor]? = nil
        
        /// For array and dictionaries (like extra or tags) you can specify a format to write the content.
        ///
        /// By default is set to `auto`.
        public var format: StructureFormatStyle = .serializedJSON
        
        /// When encoding a field which contains array or dictionary the item separator is used to compose the string.
        public var separator: String = ","
        
        /// Allows you to further customize the `Field` options per single message received.
        ///
        /// DISCUSSION:
        /// You can, for example, customize the message color based upon severity level
        /// (see `XCodeFormatter` for an example).
        /// You can customize the received `Field` instance which is a copy of self.
        public var onCustomizeForEvent: ((Event, inout Field) -> Void)?
        
        // MARK: - Internal Properties
        
        /// Specify a prefix literal to format the result of formatted.
        /// For example (`extra = { %@ }` uses the format and replace the placeholder with the value formatted.
        ///
        /// By default is set to `nil`•
        public var stringFormat: String? = nil
        
        // MARK: - Initialization
               
        /// Initialize a new `FieldsFormatter` with given identifier and an optional
        /// configuration callback.
        ///
        /// - Parameters:
        ///   - field: field identifier.
        ///   - configure: configuration callback.
        internal init(_ field: FieldIdentifier, _ configure: Configure?) {
            self.field = field
            configure?(&self)
            if self.stringFormat == nil {
                self.stringFormat = self.format.defaultStringFormatForField(field)
            }
        }
        
        public static func icon(_ configure: Configure? = nil) -> Field {
            self.init(.icon, configure)
        }
        
        public static func field(_ field: FieldIdentifier, _ configure: Configure? = nil) -> Field {
            self.init(field, configure)
        }
        
        public static func label(_ configure: Configure? = nil) -> Field {
            self.init(.label, configure)
        }
        
        public static func timestamp(style: TimestampStyle, _ configure: Configure? = nil) -> Field {
            self.init(.timestamp(style), configure)
        }
        
        public static func level(style: LevelStyle, _ configure: Configure? = nil) -> Field {
            self.init(.level(style), configure)
        }
        
        public static func callSite( _ configure: Configure? = nil) -> Field {
            self.init(.callSite, configure)
        }
        
        public static func callingThread(style: CallingThreadStyle,  _ configure: Configure? = nil) -> Field {
            self.init(.callingThread(style), configure)
        }
        
        public static func processName( _ configure: Configure? = nil) -> Field {
            self.init(.processName, configure)
        }

        public static func processID( _ configure: Configure? = nil) -> Field {
            self.init(.processID, configure)
        }
        
        public static func delimiter(style: DelimiterStyle, _ configure: Configure? = nil) -> Field {
            self.init(.delimiter(style), configure)
        }
        
        public static func literal(_ value: String, _ configure: Configure? = nil) -> Field {
            self.init(.literal(value), configure)
        }
        
        public static func tags(keys: [String]?, _ configure: Configure? = nil) -> Field {
            self.init(.tags(keys), configure)
        }
        
        public static func extra(keys: [String]?, _ configure: Configure? = nil) -> Field {
            self.init(.extra(keys), configure)
        }
        
        public static func custom(_ callback: @escaping CallbackFormatter.Callback, _ configure: Configure? = nil) -> Field {
            let formatter = CallbackFormatter(callback)
            return self.init(.custom(formatter), configure)
        }
        
        public static func customValue(_ callback: @escaping ((Event?) -> (key: String, value: String)), _ configure: Configure? = nil) -> Field {
            return self.init(.customValue(callback), configure)
        }
        
        public static func category( _ configure: Configure? = nil) -> Field {
            self.init(.category, configure)
        }
        
        public static func subsystem( _ configure: Configure? = nil) -> Field {
            self.init(.subsystem, configure)
        }
        
        public static func eventUUID( _ configure: Configure? = nil) -> Field {
            self.init(.eventUUID, configure)
        }
        
        public static func message( _ configure: Configure? = nil) -> Field {
            self.init(.message, configure)
        }
        
        public static func userId( _ configure: Configure? = nil) -> Field {
            self.init(.userId, configure)
        }
        
        public static func username( _ configure: Configure? = nil) -> Field {
            self.init(.username, configure)
        }
        
        public static func ipAddress( _ configure: Configure? = nil) -> Field {
            self.init(.ipAddress, configure)
        }
        
        public static func userData(keys: [String]? = nil, _ configure: Configure? = nil) -> Field {
            self.init(.userData(keys), configure)
        }
        
        public static func fingerprint(_ configure: Configure? = nil) -> Field {
            self.init(.fingerprint, configure)
        }
        
        public static func objectMetadata(keys: [String]? = nil, _ configure: Configure? = nil) -> Field {
            self.init(.objectMetadata(keys), configure)
        }
        
        public static func object() -> Field {
            self.init(.object, nil)
        }
        
        // MARK: - Internal Function
        
        internal func value(forEvent event: Event) -> String? {
            nil
        }
        
    }
    
    /// Represent the individual key of a formatted log when using
    /// the `FieldsFormatter` formatter.
    ///
    /// - `label`: combination of `subsystem` and `category` which identify a log (or app name if not set).
    /// - `icon`: icon representation of the log as emoji character(s).
    /// - `category`: category identifier of the parent's log.
    /// - `subsystem`: subsystem identifier of the parent's log.
    /// - `eventUUID`: identifier of the event, autoassigned.
    /// - `timestamp`: creation data of the event.
    /// - `level`: level of severity for the event.
    /// - `callSite`: line and file of the caller.
    /// - `stackFrame`: which function called the event.
    /// - `callingThread`: calling of the thread.
    /// - `processName`: name of the process.
    /// - `processID`: PID of the process.
    /// - `message`: text message of the event.
    /// - `userId`: when assigned the currently logged user id which generate the event.
    /// - `userEmail`: when assigned the currently logged user email which generate the event.
    /// - `username`: when assigned the currently logged username which generate the event.
    /// - `ipAddress`: if set the assigned logged user's ip address which generate the event.
    /// - `userData`: `keys` values for given `keys` found in user's data.
    /// - `fingerprint`: the fingerprint used for event, if not found the `scope`'s fingerprint.
    /// - `objectMetadata`: a json string representation of the event's associated object metadata.
    /// - `objectMetadataKeys`: `keys` values for given `keys` found in associated object's metadata.
    /// - `delimiter`: delimiter.
    /// - `tags`: `keys` values for given `keys` found in event's `tags`.
    /// - `extra`: `keys` values for given `keys` found in event's `extra`.
    /// - `custom`: apply custom tranformation function which receive the `event` instance.
    public enum FieldIdentifier {
        case label
        case icon
        case category
        case subsystem
        case eventUUID
        case timestamp(TimestampStyle)
        case level(LevelStyle)
        case callSite
        case stackFrame
        case callingThread(CallingThreadStyle)
        case processName
        case processID
        case message
        case userId
        case userEmail
        case username
        case ipAddress
        case userData([String]?)
        case fingerprint
        case objectMetadata([String]?)
        case object
        case delimiter(DelimiterStyle)
        case literal(String)
        case tags([String]?)
        case extra([String]?)
        case custom(EventFormatter)
        case customValue((Event?) -> (key: String, value: String)?)
        
        internal var defaultLabel: String? {
            switch self {
            case .label: return "label"
            case .category: return "category"
            case .subsystem: return "subsystem"
            case .eventUUID: return "uuid"
            case .timestamp: return "timestamp"
            case .level: return "level"
            case .callSite: return "callSite"
            case .stackFrame: return "stackFrame"
            case .callingThread: return "callingThread"
            case .processName: return "processName"
            case .processID: return "processID"
            case .message: return "message"
            case .userId: return "userId"
            case .userEmail: return "userEmail"
            case .username: return "username"
            case .ipAddress: return "ip"
            case .userData: return "userData"
            case .object: return "object"
            case .fingerprint: return "fingerprint"
            case .objectMetadata: return "objectMetadata"
            case .tags: return "tags"
            case .extra: return "extra"
            case .customValue(let function): return function(nil)?.key
            default: return nil
            }
        }
    }
    
    /// The timestamp style used to format dates.
    /// - `iso8601`: Specifies a timestamp style that uses the date format string "yyyy-MM-dd HH:mm:ss.SSS zzz".
    /// - `unix`: Specifies a UNIX timestamp indicating the number of seconds elapsed since January 1, 1970.
    /// - `xcode`· XCode format (`2009-08-30 04:54:48.128`)
    /// - `custom`: Specifies a custom date format.
    public enum TimestampStyle {
        case iso8601
        case unix
        case xcode
        case custom(String)
    }
    
    /// Specifies the manner in which `Level` values should be rendered.
    public enum LevelStyle {
        case simple
        case short
        case emoji
        case numeric
        case custom((Level) -> String)
    }
    
    /// Specify how `Level` value should be represented in text.
    /// - `capitalized`: Specifies that the `Level` should be output as a human-readable word
    ///                  with the initial capitalization.
    /// - `lowercase`: Specifies that the `Level` should be output as a human-readable word
    ///                 in all lowercase characters.
    /// - `uppercase`: Specifies that the `Level` should be output as a human-readable word in
    ///                all uppercase characters.
    /// - `numeric`: Specifies that the `rawValue` of the `Level` should be output as an integer within a string.
    /// - `colorCoded`: Specifies that the `rawValue` of the `LogSeverity` should be output as an emoji character
    ///                 whose color represents the level of severity.
    public enum TextRepresentation {
        case capitalize
        case lowercase
        case uppercase
        case numeric
        case colorCoded
    }
    
    public enum CallingThreadStyle {
        case hex
        case integer
    }
    
    public enum DelimiterStyle {
        case spacedPipe
        case spacedHyphen
        case tab
        case space
        case `repeat`(Character,Int)
        case custom(String)
        
        public var delimiter: String {
            switch self {
            case .spacedPipe:
                return " | "
            case .spacedHyphen:
                return " - "
            case .tab:
                return "\t"
            case .space:
                return " "
            case .custom(let sep):
                return sep
            case .repeat(let char, let count):
                return String(repeating: char, count: count)
            }
        }
    }
    
}

// MARK: - Foundation Extension

extension DateFormatter {
        
    /// Internal date formatter.
    fileprivate static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Date formatter for xcode styles
    fileprivate static var xcodeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Internal ISO8601 date formatter.
    fileprivate static var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
}

extension Date {
    
    public func format(style: FieldsFormatter.TimestampStyle) -> String? {
        switch style {
        case .custom(let format):
            DateFormatter.dateFormatter.dateFormat = format
            return DateFormatter.dateFormatter.string(from: self)
        case .iso8601:
            return DateFormatter.iso8601Formatter.string(from: self)
        case .unix:
            return String(self.timeIntervalSince1970)
        case .xcode:
            return DateFormatter.xcodeDateFormatter.string(from: self)
        }
    }
    
}

// MARK: - Level Extension

extension Level {
    
    public func format(style: FieldsFormatter.LevelStyle) -> String? {
        switch style {
        case .numeric:
            return String(describing: rawValue)
        case .simple:
            return description.uppercased()
        case .emoji:
            return emoji
        case .short:
            return shortDescription
        case .custom(let formatter):
            return formatter(self)
        }
    }

    public var emoji: String {
        switch self {
        case .debug, .trace:
            return "⚪️"
        case .info:
            return "🔵"
        case .notice:
            return "🟡"
        case .warning:
            return "🟠"
        case .alert, .emergency, .critical, .error:
            return "🔴"
        }
    }
    
    public var shortDescription: String {
        switch self {
        case .emergency: return "EMRG"
        case .alert:     return "ALRT"
        case .critical:  return "CRTC"
        case .error:     return "ERRR"
        case .warning:   return "WARN"
        case .notice:    return "NTCE"
        case .info:      return "INFO"
        case .debug:     return "DEBG"
        case .trace:     return "TRCE"
        }
    }
    
}

// MARK: - Colorization

public protocol FieldsFormatterColor {
    
    /// Colorize string with self.
    ///
    /// - Parameter string: string to colorize.
    /// - Returns: `String`
    func colorize(_ string: String) -> String
    
}

// MARK: - FieldsFormatter.CallingThreadStyle

extension FieldsFormatter.CallingThreadStyle {
    
    /// Format the calling thread based upon given style.
    ///
    /// - Parameter callingThreadID: thread id to format.
    /// - Returns: String
    public func format(_ callingThreadID: UInt64) -> String {
        switch self {
        case .hex:      return String(format: "%08X", callingThreadID)
        case .integer:  return String(describing: callingThreadID)
        }
    }

}

// MARK: - FieldsFormatter.StructureFormatStyle

extension FieldsFormatter {
        
    /// Defines how the structures like array or dictionaries are encoded
    /// inside the formatted string.
    /// - `serializedJSON`: structure is kept, this is useful when you have a format as JSON which support the
    /// - `list`: as list (a bullet list for each key (example: `\t- key1 = value1\n\t- key2 = value2...`)
    /// - `table`: formatted as table with two columns (one for keys and one for values).
    /// - `queryString`: formatted as query string (example `keys={k1=v1,k2=v2}`)
    public enum StructureFormatStyle {
        case serializedJSON
        case list
        case table
        case queryString
        
        public static var tableInfoMaxColumnsWidth: (keyColumn: Int?, valueColumn: Int?)
        
        // MARK: - Internal Functions
        
        /// Return the default string format to compose special styles.
        ///
        /// - Parameter title: title of prefix.
        /// - Returns: `String?`
        internal func defaultStringFormatForField(_ field: FieldIdentifier) -> String? {
            switch field {
            case .tags, .extra, .userData, .objectMetadata:
                switch self {
                case .queryString:
                    return "\(field.tableTitle?.lowercased() ?? "")={%@}"
                case .list:
                    return "\(field.tableTitle?.lowercased() ?? "")={%@}"
                case .table:
                    return "\n%@"
                default:
                    return nil
                }
            default:
                return nil
            }
        }
        
        /// Produce a string representation of a complex object based upon the style of the field.
        ///
        /// - Parameters:
        ///   - value: value to format.
        ///   - field: field target.
        /// - Returns: `String?`
        internal func stringify(_ value: Any?, forField field: Field, includeNilKeys: Bool) -> String? {
            guard let value = value else { return nil }

            switch self {
            case .serializedJSON:
                return stringifyAsSerializedJSON(value, forField: field)
            case .list:
                return stringifyAsList(value, forField: field, includeNilKeys: includeNilKeys)
            case .table:
                return stringifyAsTable(value, forField: field, includeNilKeys: includeNilKeys)
            case .queryString:
                return stringifyAsQueryString(value, forField: field, includeNilKeys: includeNilKeys)
            }
        }
        
        // MARK: - Private Functions
        
        private func stringifyAsTable(_ value: Any, forField field: Field, includeNilKeys: Bool) -> String? {
            let keyColumnTitle = field.field.tableTitle?.uppercased() ?? "KEY"
            
            switch value {
            case let stringValue as String:
                return stringValue
            case let dictValue as [String: Any?]:
                let rows: [String] = dictValue.keys.sorted().reduce(into: [String]()) { list, key in
                    if let value = dictValue[key] {
                        if value.isNil == false { // unwrapped has a value
                            list.append(key)
                            list.append(String(describing: value!))
                        } else if includeNilKeys {
                            list.append(key)
                            list.append("nil")
                        }
                    }
                }
                return createKeyValueTableWithRows(rows, keyColumnTitle: keyColumnTitle)?.stringValue
            case let arrayValue as [Any?]:
                let rows = arrayValue.map({ String(describing: $0) })
                return createKeyValueTableWithRows(rows, keyColumnTitle: keyColumnTitle)?.stringValue
            default:
                return nil
            }
        }
        
        private func stringifyAsList(_ value: Any, forField field: Field, includeNilKeys: Bool) -> String? {
            switch value {
            case let stringValue as String:
                return stringValue
            case let dictValue as [String: Any?]:
                let value = dictValue.keys.sorted().reduce(into: [String]()) { list, key in
                    if let value = dictValue[key] {
                        if value.isNil == false {
                            list.append("\t- \(key)=\"\(String(describing: value!))\"")
                        } else if includeNilKeys {
                            list.append("\t- \(key)=nil")
                        }
                    }
                }.joined(separator: "\n")
                return "\n\(value)\n"
            case let arrayValue as [Any?]:
                let value = arrayValue.compactMap {
                    guard let value = $0 else {
                        return nil
                    }
                    return "\t - \(String(describing: value))"
                }.joined(separator: "\n")
                return "\n\(value)\n"
            default:
                return nil
            }
        }
        
        private func stringifyAsQueryString(_ value: Any, forField field: Field, includeNilKeys: Bool) -> String? {
            switch value {
            case let stringValue as String:
                return stringValue
            case let dictValue as [String: Any?]:
                guard dictValue.isEmpty == false else {
                    return nil
                }
                
                var components = [String]()
                
                for key in dictValue.keys.sorted() {
                    if let value = dictValue[key]  {
                        if value.isNil == false {
                            components.append("\(key)=\(String(describing: value!))")
                        } else if includeNilKeys {
                            components.append("\(key)=nil")
                        }
                    }
                }
                
                return components.joined(separator: "&")
            case let arrayValue as [Any?]:
                guard arrayValue.isEmpty == false else {
                    return nil
                }
                
                return arrayValue.map({ String(describing: $0) }).joined(separator: field.separator)
            default:
                return nil
            }
        }
        
        private func stringifyAsSerializedJSON(_ value: Any, forField field: Field) -> String? {
            switch value {
            case let stringValue as String:
                return stringValue
            case let dictValue as [String: Any?]:                
                let serializableDictionary: [String: SerializableData] = dictValue.compactMapValues({
                    guard let serializable = $0 as? SerializableData else {
                        return nil
                    }
                    
                    return serializable.asString() ?? serializable.asData()
                })
                
                guard serializableDictionary.isEmpty == false else {
                    return nil
                }
                
                let json = try? JSONSerialization.data(withJSONObject: serializableDictionary, options: .sortedKeys)
                return json?.asString()
            case let arrayValue as [Any?]:
                guard arrayValue.isEmpty == false else {
                    return nil
                }
                
                return arrayValue.map({ String(describing: $0) }).joined(separator: field.separator)
            default:
                return String(describing: value)
            }
        }
        
        private func createKeyValueTableWithRows(_ rows: [String], keyColumnTitle: String) -> ASCIITable? {
            guard !rows.isEmpty else {
                return nil
            }
            
            let columnIdentifier = ASCIITable.Column { col in
                col.footer = .init({ footer in
                    footer.border = .boxDraw.heavyHorizontal
                })
                col.header = .init(title: keyColumnTitle, { header in
                    header.fillCharacter = " "
                    header.verticalPadding = .init({ padding in
                        padding.top = 0
                        padding.bottom = 0
                    })
                })
                col.verticalAlignment = .top
                col.maxWidth = StructureFormatStyle.tableInfoMaxColumnsWidth.keyColumn
                col.horizontalAlignment = .leading
            }
            
            
            let columnValues = ASCIITable.Column { col in
                col.footer = .init({ footer in
                    footer.border = .boxDraw.heavyHorizontal
                })
                col.header = .init(title: "VALUE", { header in
                    header.fillCharacter = " "
                    header.verticalPadding = .init({ padding in
                        padding.top = 0
                        padding.bottom = 0
                    })
                })
                col.maxWidth =  StructureFormatStyle.tableInfoMaxColumnsWidth.valueColumn
                col.horizontalAlignment = .leading
            }
            
            let columns = ASCIITable.Column.configureBorders(in: [columnIdentifier, columnValues], style: .light)
            return ASCIITable(columns: columns, content: rows)
            
        }
        
    }
    
}

// MARK: - String Extension

extension String {
    
    /// Apply transformations specified by the field to the receiver.
    ///
    /// - Parameter field: field.
    /// - Returns: `String`
    public func applyFormattingOfField(_ field: FieldsFormatter.Field) -> String {
        var value = self
        
        // Custom text transforms
        for transform in field.transforms ?? [] {
            value = transform(value)
        }
        
        // Formatting with pad and trucation
        if let format = field.stringFormat {
            value = String.format(format, value: value)
        }
        value = value.trunc(field.truncate)
        value = value.padded(field.padding)
        
        // Apply colorazation (for terminal or xcode if available)
        if let colors = field.colors {
            for color in colors {
                value = color.colorize(value)
            }
        }
        
        return value
    }
    
}
