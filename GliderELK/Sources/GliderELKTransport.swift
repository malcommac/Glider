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
import Glider
import NIO
import NIOConcurrencyHelpers
import Logging
import AsyncHTTPClient

public class GliderELKTransport: Transport {
    
    // MARK: - Public Properties
    
    /// GCD queue.
    public var queue: DispatchQueue?
    
    /// Is logging enabled.
    public var isEnabled: Bool = true
    
    /// Configuration set.
    public let configuration: Configuration
    
    // MARK: - Private Properties
    
    /// The `HTTPClient` which is used to create the `HTTPClient.Request`
    private var httpClient: HTTPClient
    
    /// The log storage byte buffer which serves as a cache of the log data entires
    private var byteBuffer: ByteBuffer
    
    /// Keeps track of how much memory is allocated in total
    public var totalByteBufferSize: Int?
    
    /// Created during scheduling of the upload function to Logstash, provides the ability to cancel the uploading task
    private var uploadTask: RepeatedTask?
    
    /// Semaphore to adhere to the maximum memory limit
    private let semaphore = DispatchSemaphore(value: 0)
    
    /// Manual counter of the semaphore (since no access to the internal one of the semaphore)
    private var semaphoreCounter: Int = 0
    
    /// Provides thread-safe access to the log storage byte buffer
    private let byteBufferLock = ConditionLock(value: false)
    
    /// The `HTTPClient.Request` which stays consistent (except the body) over all uploadings to Logstash
    private var httpRequest: HTTPClient.Request?
    
    // MARK: - Initialization
    
    /// Initialize with a given configuration.
    ///
    /// - Parameter configuration: configuration.
    public init(configuration: Configuration) throws {
        self.configuration = configuration
        self.httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(configuration.eventLoopGroup),
            configuration: HTTPClient.Configuration(),
            backgroundActivityLogger: configuration.backgroundActivityLogger
        )
        
        self.byteBuffer = ByteBufferAllocator().buffer(capacity: configuration.logStorageSize)
        self.totalByteBufferSize = byteBuffer.capacity
        self.uploadTask = scheduleUploadTask(initialDelay: configuration.uploadInterval)
    }
    
    /// Initialize with a given configuration.
    ///
    /// - Parameters:
    ///   - hostname: hostname.
    ///   - port: port number.
    ///   - builder: builder function.
    public convenience init(hostname: String, port: Int, _ builder: ((inout Configuration) -> Void)? = nil) throws {
        try self.init(configuration: Configuration(hostname: hostname, port: port, builder))
    }
    
    // MARK: - Conformance
    
    public func record(event: Event) -> Bool {
        guard isEnabled else { return false }
        
        return true
    }
    
    // MARK: - Private Functions
    
    /// Schedules the `uploadLogData` function with a certain `TimeAmount` as `initialDelay` and `delay` (delay between repeating the task)
    private func scheduleUploadTask(initialDelay: TimeAmount) -> RepeatedTask {
        configuration.eventLoopGroup
            .next()
            .scheduleRepeatedTask(
                initialDelay: initialDelay,
                delay: configuration.uploadInterval,
                notifying: nil,
                uploadLogData
            )
    }
    
    /// Uploads the stored log data in the `ByteBuffer` to Logstash.
    ///
    /// NOTE:
    /// - Never called directly, its only scheduled via the `scheduleUploadTask` function
    /// - This function is thread-safe and designed to only block the stored log data `ByteBuffer`
    ///   for a short amount of time (the time it takes to duplicate this bytebuffer). Then, the "original"
    ///   stored log data `ByteBuffer` is freed and the lock is lifted
    /// - Parameter task: task
    private func uploadLogData(_ task: RepeatedTask? = nil) {
        guard byteBuffer.readableBytes != 0 else {
            return
        }

        // If total byte buffer size is exceeded, wait until the size is decreased again
        if totalByteBufferSize! + byteBuffer.capacity > configuration.maximumTotalLogStorageSize {
            semaphoreCounter -= 1
            semaphore.wait()
        }
        
        byteBufferLock.lock()

        totalByteBufferSize! += byteBuffer.capacity

        // Copy log data into a temporary byte buffer
        // This helps to prevent a stalling request if more than the max. buffer size
        // log messages are created during uploading of the "old" log data
        var tempByteBuffer = ByteBufferAllocator().buffer(capacity: byteBuffer.readableBytes)
        tempByteBuffer.writeBuffer(&byteBuffer)
        
        byteBuffer.clear()
        
        byteBufferLock.unlock(withValue: false)
        
        // Setup of HTTP requests that is used for all transmissions
        if httpRequest == nil {
            httpRequest = createHTTPRequest()
        }
        
        var pendingHTTPRequests: [EventLoopFuture<HTTPClient.Response>] = []
    
        // Read data from temp byte buffer until it doesn't contain any readable bytes anymore
        while tempByteBuffer.readableBytes != 0 {
            guard let logDataSize: Int = tempByteBuffer.readInteger(),
                  let logData = tempByteBuffer.readSlice(length: logDataSize) else {
                      fatalError("Error reading log data from byte buffer")
                  }
            
            guard var httpRequest = httpRequest else {
                fatalError("HTTP Request not properly initialized")
            }
            
            httpRequest.body = .byteBuffer(logData)
            
            pendingHTTPRequests.append(
                httpClient.execute(request: httpRequest)
            )
        }
        
        // Wait until all HTTP requests finished, then signal waiting threads
        _ = EventLoopFuture<HTTPClient.Response>
            .whenAllComplete(pendingHTTPRequests, on: configuration.eventLoopGroup.next())
            .map { [weak self] results in
                guard let self = self else { return }
                
                _ = results.map { result in
                    switch result {
                    case .failure(let error):
                        self.configuration.backgroundActivityLogger.log(
                            level: .warning,
                            "Error during sending logs to Logstash - \(error)",
                            metadata: [
                                "hostname": .string(self.configuration.hostname),
                                "port": .string("\(self.configuration.port)")
                            ]
                        )
                    case .success(let response):
                        if response.status != .ok {
                            self.configuration.backgroundActivityLogger.log(
                                level: .warning,
                                "Error during sending logs to Logstash - \(String(describing: response.status))",
                                metadata: [
                                    "hostname": .string(self.configuration.hostname),
                                    "port": .string("\(self.configuration.port)")
                                ]
                            )
                        }
                    }
                }
                
                self.byteBufferLock.lock()
                
                // Once all HTTP requests are completed, signal that new memory space is available
                if self.totalByteBufferSize! <= self.configuration.maximumTotalLogStorageSize {
                    // Only signal if the semaphore count is below 0 (so at least one thread is blocked)
                    if self.semaphoreCounter < 0 {
                        self.semaphoreCounter += 1
                        self.semaphore.signal()
                    }
                }
                
                self.totalByteBufferSize! -= self.byteBuffer.capacity
                self.byteBufferLock.unlock()
            }
    }
    
    
    /// Creates the HTTP request which stays constant during the entire lifetime of the `LogstashLogHandler`
    /// Sets some default headers, eg. a dynamically adjusted "Keep-Alive" header
    ///

    
    /// Creates the HTTP request.
    ///
    /// - Returns: HTTPClient.Request
    private func createHTTPRequest() -> HTTPClient.Request? {
        let scheme = configuration.useHTTPS ? "https" : "http"
        var httpRequest = try? HTTPClient.Request(url: "\(scheme)://\(configuration.hostname):\(configuration.port)",
                                                  method: .POST)
        
        // Set headers that always stay consistent over all requests
        httpRequest?.headers.add(name: "Content-Type", value: "application/json")
        httpRequest?.headers.add(name: "Accept", value: "application/json")
        
        // Keep-alive header to keep the connection open
        httpRequest?.headers.add(name: "Connection", value: "keep-alive")

        if configuration.uploadInterval <= TimeAmount.seconds(10) {
            httpRequest?.headers.add(name: "Keep-Alive",
                                    value: "timeout=\(Int((configuration.uploadInterval.rawSeconds * 3).rounded(.toNearestOrAwayFromZero))), max=100")
        } else {
            httpRequest?.headers.add(name: "Keep-Alive",
                                    value: "timeout=30, max=100")
        }

        return httpRequest
    }
    
}
