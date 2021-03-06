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
import Darwin.C.stdio

/// This transport  output that can output text messages to POSIX stream.
open class POSIXStreamTransport: Transport {
    
    // MARK: - Public Properties
    
    /// Configuration.
    public let configuration: Configuration
    
    /// Dispatch queue.
    open var queue: DispatchQueue?
    
    /// Transport is enabled.
    open var isEnabled: Bool = true
    
    /// Minumum accepted level for this transport.
    /// `nil` means every passing message level is accepted.
    open var minimumAcceptedLevel: Level? = nil
    
    // MARK: - Initialization
    
    /// Initialize with configuration.
    ///
    /// - Parameter configuration: configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.isEnabled = configuration.isEnabled
        self.minimumAcceptedLevel = configuration.minimumAcceptedLevel
        self.queue = configuration.queue
    }
    
    /// Initialize a new `POSIXStreamTransport` instance.
    ///
    /// - Parameter builder: builder configuration settings.
    public convenience init(_ builder: ((inout Configuration) -> Void)? = nil) {
        self.init(configuration: Configuration(builder))
    }
    
    /// Create a `stdout` transport formatter.
    /// - Parameters:
    ///   - formatters: formatters to use. When not specificed `TerminalFormatter` is used.
    ///   - queue: queue to use for dispatch. When not specified a new queue is created.
    /// - Returns: `StdStreamTransport`
    public static func stdOut(formatters: [EventFormatter] = [TerminalFormatter()],
                              queue: DispatchQueue = DispatchQueue(label: "Glider.\(UUID().uuidString)")) -> POSIXStreamTransport {
        POSIXStreamTransport {
            $0.stream = Darwin.stdout
            $0.queue = queue
            $0.formatters = formatters
        }
    }
    
    /// Create a `stderr` transport formatter.
    /// - Parameters:
    ///   - formatters: formatters to use. When not specificed `TerminalFormatter` is used.
    ///   - queue: queue to use for dispatch. When not specified a new queue is created.
    /// - Returns: `StdStreamTransport`
    public static func stdErr(formatters: [EventFormatter] = [TerminalFormatter()],
                              queue: DispatchQueue = DispatchQueue(label: "Glider.\(UUID().uuidString)")) -> POSIXStreamTransport {
        POSIXStreamTransport {
            $0.stream = Darwin.stderr
            $0.queue = queue
            $0.formatters = formatters
        }
    }
    
    
    // MARK: - Conformance
    
    public func record(event: Event) -> Bool {        
        guard let message = configuration.formatters.format(event: event)?.asString(),
              message.isEmpty == false else {
            return false
        }
        
        return fputs(message + "\n", configuration.stream) != EOF
    }
    
}

// MARK: - Configuration

extension POSIXStreamTransport {
    
    public struct Configuration {
        
        // MARK: - Configuration
        
        /// Is the transport enabled. By default is set to `true`.
        public var isEnabled = true
        
        /// Dispatch queue.
        public var queue = DispatchQueue(label: "Glider.\(UUID().uuidString)")

        /// POSIX stream.
        public var stream: UnsafeMutablePointer<FILE> = Darwin.stdout
        
        /// Formatter used to transform a payload into a string.
        public var formatters: [EventFormatter] = [
            TerminalFormatter()
        ]
        
        /// Minumum accepted level for this transport.
        /// `nil` means every passing message level is accepted.
        public var minimumAcceptedLevel: Level? = nil
        
        // MARK: - Initialization
        
        /// Initialize a new `POSIXStreamTransport`.
        /// - Parameter builder: builder settings.
        public init(_ builder: ((inout Configuration) -> Void)?) {
            builder?(&self)
        }
        
    }
    
}
