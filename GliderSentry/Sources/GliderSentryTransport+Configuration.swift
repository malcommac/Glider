//
//  GliderSentry
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
import Sentry

extension GliderSentryTransport {
    
    public struct Configuration {
        
        // MARK: - Public Properties
        
        /// Is the transport enabled. By default is set to `true`.
        public var isEnabled = true
        
        /// This is the SDK configuration object. You should set a non `nil` value here if you want
        /// Glider's `SentryTransport` needs to initialize the SDK for you.
        /// If you have the SDK already initialized at this time leave this `nil`.
        /// `SentryTransport` will always use the static methods of `SentrySDK` to dispatch events.
        public var sdkConfiguration: Sentry.Options?
        
        /// Formatter used to transform a payload into a string.
        public var formatters = [EventFormatter]()
        
        /// Matches on the name of the logger, which is useful to combine all messages of a logger together.
        ///  This match is case sensitive.
        public var loggerName: String?
        
        /// Minumum accepted level for this transport.
        /// `nil` means every passing message level is accepted.
        public var minimumAcceptedLevel: Level? = nil
        
        /// Generally, the tag accepts any value, but it's intended to refer to your code deployments'
        /// naming convention, such as development, testing, staging, or production.
        /// More on <https://docs.sentry.io/product/sentry-basics/environments/>.
        public var environment: String?
        
        // MARK: - Initialixation
        
        /// Initialize a new Sentry transport configuration.
        ///
        /// - Parameter builder: builder configuration callback.
        public init(_ builder: ((inout Configuration) -> Void)?) {
            builder?(&self)
        }
        
    }
    
}
