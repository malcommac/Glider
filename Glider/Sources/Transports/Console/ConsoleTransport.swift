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

/// `ConsoleTransport` is used to print log directly on Xcode or other IDE console.
open class ConsoleTransport: Transport {
    
    // MARK: - Public Properties
    
    /// GCD queue.
    open var queue: DispatchQueue? = nil
    
    /// Transport is enabled.
    open var isEnabled: Bool = true
    
    /// Configuration.
    public let configuration: Configuration
    
    /// Minumum accepted level for this transport.
    /// `nil` means every passing message level is accepted.
    open var minimumAcceptedLevel: Level? = nil
    
    // MARK: - Initialization
    
    /// Initialize with configuration.
    ///
    /// - Parameter configuration: configuration.
    public init(configuration: Configuration) {
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration
        self.minimumAcceptedLevel = configuration.minimumAcceptedLevel
    }
    
    /// Initialize new console transport.
    ///
    /// - Parameter builder: builder to setup additional configurations.
    public convenience init(_ builder: ((inout Configuration) -> Void)? = nil) {
        self.init(configuration: Configuration(builder))
    }
    
    // MARK: - Public Functions
    
    public func record(event: Event) -> Bool {        
        guard let message = configuration.formatters.format(event: event)?.asString(),
              message.isEmpty == false else {
            return false
        }
        
        print(message)
        return true
    }
    
}

// MARK: - Configuration

extension ConsoleTransport {
    
    public struct Configuration {
        
        // MARK: - Public Properties
        
        /// Is the transport enabled. By default is set to `true`.
        public var isEnabled = true
        
        /// GCD queue. If not set a default one is created for you.
        public var queue = DispatchQueue(label: "Glider.\(UUID().uuidString)")

        /// Formatter used to transform a payload into a string.
        public var formatters = [EventFormatter]()
        
        /// Minumum accepted level for this transport.
        /// `nil` means every passing message level is accepted.
        public var minimumAcceptedLevel: Level? = nil
        
        // MARK: - Initialization
        
        /// Initialize a new configuration for `ConsoleTransport`.
        ///
        /// - Parameters:
        ///   - formatters: formatters to use. Ignore to use the default `XCodeFormatter`.
        ///   - builder: builder configuration function.
        public init(formatters: [EventFormatter] = [XCodeFormatter.init()],
                    _ builder: ((inout Configuration) -> Void)?) {
            self.formatters = formatters
            builder?(&self)
        }
        
    }
    
}
