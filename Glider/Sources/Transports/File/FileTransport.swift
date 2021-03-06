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

/// A `FileTransport` implementation that appends log entries to a file.
///
/// NOTE:
/// `FileTransport` is a simple log appender that provides no mechanism
/// for file rotation or truncation. Unless you manually manage the log file when
/// a `FileLogRecorder` doesn't have it open, you will end up with an ever-growing
/// file.
/// Use a `RotatingLogTrasport` instead if you'd rather not have to concern
/// yourself with such details.
open class FileTransport: Transport {
    
    // MARK: - Public Properties
    
    /// the GCD queue that will be used when executing tasks related to
    /// the receiver.
    /// Log formatting and recording will be performed using this queue.
    ///
    /// A serial queue is typically used, such as when the underlying
    /// log facility is inherently single-threaded and/or proper message ordering
    /// wouldn't be ensured otherwise. However, a concurrent queue may also be
    /// used, and might be appropriate when logging to databases or network
    /// endpoints.
    public var queue: DispatchQueue?
    
    /// Transport is enabled.
    public var isEnabled: Bool = true
    
    /// Configuration settings.
    public let configuration: Configuration
    
    /// Minumum accepted level for this transport.
    /// `nil` means every passing message level is accepted.
    open var minimumAcceptedLevel: Level? = nil
    
    /// Current file size (expressed in bytes).
    public var size: UInt64 {
        fileHandle?.seekToEndOfFile() ?? 0
    }
    
    /// Newline characters, by default `\n` are used.
    open var newlines = "\r\n" {
        didSet {
            self.newLinesData = newlines.data(using: .utf8)
        }
    }
    
    // MARK: - Private Functions
    
    /// New lines data.
    private var newLinesData: Data?
    
    /// Pointer to the file handler.
    private lazy var fileHandle: FileHandle? = {
        FileHandle(forWritingAtPath: configuration.fileURL.path)
    }()
    
    private let handler: UnsafeMutablePointer<FILE>?
    
    // MARK: - Initialization
    
    /// Initialize with configuration.
    ///
    /// - Parameter configuration: configuration.
    public init(configuration: Configuration) throws {
        self.configuration = configuration
        self.isEnabled = configuration.isEnabled
        self.minimumAcceptedLevel = configuration.minimumAcceptedLevel
        
        let fileHandler = fopen(configuration.fileURL.path, "a")
        guard fileHandler != nil else {
            throw GliderError(message: "Failed to open handle for file writing at path: \(configuration.fileURL.path)")
        }
     
        self.queue = configuration.queue
        self.handler = fileHandler
        self.newLinesData = configuration.newlines.data(using: .utf8)
    }
    
    /// Initialize a new `FileTransport` instance to use the given file path
    /// and event formatters. This will fail if `filePath` could not
    /// be opened for writing.
    ///
    /// - Parameters:
    ///   - fileURL: file URL for writing logs.
    ///   - builder: builder to configure additional settings.
    public convenience init(fileURL: URL, _ builder: ((inout Configuration) -> Void)? = nil) throws {
        try self.init(configuration: Configuration(fileURL: fileURL, builder))
    }
    
    deinit {
        // we've implemented FileLogRecorder as a class so we
        // can have a de-initializer to close the file
        close()
    }
    
    // MARK: - Public Functions
    
    open func record(event: Event) -> Bool {
        guard let message = configuration.formatters.format(event: event)?.asData(),
              message.isEmpty == false else {
            return false
        }
        
        fileHandle?.seekToEndOfFile()
        
        fileHandle?.write(message)
        if let newLinesData = newLinesData {
            fileHandle?.write(newLinesData)
        }

        return true
    }
    
    /// Close pointer to file handler.
    open func close() {
        try? fileHandle?.close()
        fileHandle = nil
    }
    
}

// MARK: - FileTransport.Configuration

extension FileTransport {
    
    public struct Configuration {
        
        // MARK: - Public Properties
        
        /// Is the transport enabled. By default is set to `true`.
        public var isEnabled = true
        
        /// URL of the local file where the data is stored.
        /// The containing directory must exist and be writable by the process.
        /// If the file does not yet exist, it will be created;
        /// if it does exist, new log messages will be appended to the end of the file.
        public var fileURL: URL
        
        /// Newline characters, by default `\r\n` are used.
        public var newlines = "\r\n"
        
        /// An array of `LogFormatter`s to use for formatting log entries to be
        /// recorded by the receiver. Each formatter is consulted in sequence,
        /// and the formatted string returned by the first formatter to yield a
        /// non-`nil` value will be recorded. If every formatter returns `nil`,
        /// the log entry is silently ignored and not recorded.
        public var formatters: [EventFormatter] = [
            FieldsFormatter.standard()
        ]
        
        /// the GCD queue that will be used when executing tasks related to
        /// the receiver.
        /// Log formatting and recording will be performed using this queue.
        ///
        /// A serial queue is typically used, such as when the underlying
        /// log facility is inherently single-threaded and/or proper message ordering
        /// wouldn't be ensured otherwise. However, a concurrent queue may also be
        /// used, and might be appropriate when logging to databases or network
        /// endpoints.
        public var queue = DispatchQueue(label: "Glider.\(UUID().uuidString)")

        /// Minumum accepted level for this transport.
        /// `nil` means every passing message level is accepted.
        public var minimumAcceptedLevel: Level? = nil
        
        // MARK: - Initialization
        
        /// Initialize a new `FileTransport` service.
        ///
        /// - Parameters:
        ///   - fileURL: file url where the data is stored.
        ///   - builder: builder callback to configure additional options.
        public init(fileURL: URL, _ builder: ((inout Configuration) -> Void)?) {
            self.fileURL = fileURL
            builder?(&self)
        }
        
    }
    
}
