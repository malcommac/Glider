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

open class HTTPTransport: Transport, AsyncTransportDelegate {
    
    // MARK: - Public Properties
    
    /// GCD queue.
    public var queue: DispatchQueue?
    
    /// Transport is enabled.
    public var isEnabled: Bool = true
    
    /// Configuration used to prepare the transport.
    public let configuration: Configuration
    
    /// Minumum accepted level for this transport.
    /// `nil` means every passing message level is accepted.
    public var minimumAcceptedLevel: Level? = nil
    
    /// Count running operations.
    public var runningOperations: Int {
        networkQueue.operationCount
    }
    
    /// Delegate to manage events and behaviour of the transport layer.
    public private(set) weak var delegate: HTTPTransportDelegate?
    
    // MARK: - Private Properties
    
    /// Operation Queue
    private var networkQueue = OperationQueue()
    
    /// Async transporter.
    private var asyncTransport: AsyncTransport?
    
    // MARK: - Initialization
    
    public init(delegate: HTTPTransportDelegate, configuration: Configuration) throws {
        self.delegate = delegate
        self.configuration = configuration
        self.isEnabled = configuration.isEnabled
        self.minimumAcceptedLevel = configuration.minimumAcceptedLevel
        self.queue = configuration.queue
        self.asyncTransport = try AsyncTransport(delegate: self,
                                                 configuration: configuration.asyncTransportConfiguration)
        self.asyncTransport?.queue = self.queue
                
        defer {
            self.networkQueue.maxConcurrentOperationCount = configuration.maxConcurrentRequests
        }
    }
    
    /// Initialize a new HTTP Transport for generic HTTP log sends.
    /// - Parameter builder: configuration builder callback.
    public convenience init(delegate: HTTPTransportDelegate, _ builder: ((inout Configuration) -> Void)? = nil) throws {
        try self.init(delegate: delegate, configuration: Configuration(builder))
    }
    
    // MARK: - Conformance
    
    public func record(event: Event) -> Bool {
        asyncTransport?.record(event: event) ?? false // forward to async transport
    }
    
    // MARK: - AsyncTransportDelegate
    
    public func asyncTransport(_ transport: AsyncTransport,
                               canSendPayloadsChunk chunk: AsyncTransport.Chunk,
                               onCompleteSendTask completion: @escaping ((ChunkCompletionResult) -> Void)) {
        
        // Get the list of URLRequests to execute for each received chunk.
        guard let chuckURLRequests = delegate?.httpTransport(self, prepareURLRequestsForChunk: chunk) else {
            fatalError("HTTPTransport's delegate not implement httpTransport(:prepareURLRequestsForChunk:)")
        }
        
        // Encapsulate each request in an async operation
        let operations: [AsyncURLRequestOperation] = chuckURLRequests.map { urlRequest in
            let op = AsyncURLRequestOperation(request: urlRequest, transport: self)
            op.onComplete = { [weak self] result in

                // alert delegate
                self?.delegate?.httpTransport(self!, didFinishRequest: urlRequest, withResult: result)

                // retry
                if case .failure(let error) = result {
                    completion(.chunkFailed(error))
                }
            }
            return op
        }
        
        // Enqueue
        networkQueue.addOperations(operations, waitUntilFinished: false)
    }
    
    public func asyncTransport(_ transport: AsyncTransport,
                               didFailWithError error: Error) {
        
    }
    
    public func asyncTransport(_ transport: AsyncTransport,
                               didFinishChunkSending sentEvents: Set<String>,
                               willRetryEvents unsentEventsToRetry: [String : Error],
                               discardedIDs: Set<String>) {
        
    }
    
    public func asyncTransport(_ transport: AsyncTransport,
                               sentEventIDs: Set<String>) {
        
    }
    
    public func asyncTransport(_ transport: AsyncTransport,
                               discardedEventsFromBuffer: Int64) {
        
    }
    
}

// MARK: - HTTPTransport.Configuration

extension HTTPTransport {
    
    public struct Configuration {
        
        // MARK: - Public Properties
        
        /// Is the transport enabled. By default is set to `true`.
        public var isEnabled = true
        
        /// The value in this property affects only the operations that
        /// the current queue has executing at the same time.
        ///
        /// By default is set to 3.
        public var maxConcurrentRequests: Int = 3
        
        /// URL Session used to send data.
        /// By default `.default` is used
        public var urlSession: URLSession
        
        /// Formatters set.
        ///
        /// NOTE:
        /// This is a derivate properties of the `AsyncTransport.Configuration`,
        /// it will set automatically the underlying AsyncTransport.Configuration.
        public var formatters: [EventFormatter] {
            set { asyncTransportConfiguration.formatters = newValue }
            get { asyncTransportConfiguration.formatters }
        }
        
        /// Limit cap for stored message.
        ///
        /// NOTE:
        /// This is a derivate properties of the `AsyncTransport.Configuration`,
        /// it will set automatically the underlying AsyncTransport.Configuration.
        public var maxEntries: Int {
            set { asyncTransportConfiguration.maxRetries = newValue }
            get { asyncTransportConfiguration.maxRetries }
        }

        /// Size of the chunks (number of payloads) sent at each dispatch event.
        ///
        /// NOTE:
        /// This is a derivate properties of the `AsyncTransport.Configuration`,
        /// it will set automatically the underlying AsyncTransport.Configuration.
        public var chunkSize: Int {
            set { asyncTransportConfiguration.chunksSize = newValue }
            get { asyncTransportConfiguration.chunksSize }
        }
        
        /// Automatic interval for flushing data in buffer.
        ///
        /// NOTE:
        /// This is a derivate properties of the `AsyncTransport.Configuration`,
        /// it will set automatically the underlying AsyncTransport.Configuration.
        public var autoFlushInterval: TimeInterval? {
            set { asyncTransportConfiguration.autoFlushInterval = newValue }
            get { asyncTransportConfiguration.autoFlushInterval }
        }
        
        /// GCD Queue.
        public var queue = DispatchQueue(label: "Glider.\(UUID().uuidString)")

        /// Minumum accepted level for this transport.
        /// `nil` means every passing message level is accepted.
        public var minimumAcceptedLevel: Level? = nil
        
        // MARK: - Private Properties
        
        /// Async transport used to configure the underlying service.
        /// By default a default `AsyncTransport` class with default settings is used.
        internal var asyncTransportConfiguration: AsyncTransport.Configuration
        
        // MARK: - Initialization
        
        /// Initialize a new default `HTTPTransport` instance.
        public init(_ builder: ((inout Configuration) -> Void)?) throws {
            self.asyncTransportConfiguration = .init()
            self.urlSession = URLSession(configuration: .default)
            builder?(&self)
        }
        
    }
    
}

// MARK: - HTTPTransportDelegate

public protocol HTTPTransportDelegate: AnyObject {
    
    /// This method is called when a new chunk of payloads can be sent over the network.
    /// In this method you should transform a chunk of payloads in one or more `URLRequest`s
    /// to enqueue into the internal network queue manager.
    ///
    /// - Parameters:
    ///   - transport: transport instance.
    ///   - chunk: chunk of payloads to send.
    /// - Returns: transformed `[URLRequest]` instances.
    func httpTransport(_ transport: HTTPTransport,
                       prepareURLRequestsForChunk chunk: AsyncTransport.Chunk) -> [HTTPTransportRequest]
    
    /// Called when a new request is executed.
    ///
    /// - Parameters:
    ///   - transport: transport instance.
    ///   - request: request executed.
    ///   - result: result obtained.
    func httpTransport(_ transport: HTTPTransport,
                       didFinishRequest request: HTTPTransportRequest, withResult result: AsyncURLRequestOperation.Response)
    
}

