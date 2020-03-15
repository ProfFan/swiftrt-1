//******************************************************************************
// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

//==============================================================================
/// Context
/// Manages the scope for the current devices, log, and error handlers
public struct Context {
    /// specifies whether operators in the current scope are
    /// evaluated for inferring or training
    @usableFromInline
    static var evaluationModeStack: [EvaluationMode] = [.inferring]
    /// the time that the platform was first accessed
    @usableFromInline
    static var startTime = Date()
    /// the log output object
    @usableFromInline
    static var logWriter: Log = Log()
    /// a platform instance unique id for queue events
    @usableFromInline
    static var queueEventCounter: Int = 0
    /// counter for unique buffer ids
    @usableFromInline
    static var bufferIdCounter: Int = 0

    /// a static instance of the compute platform
    /// The platform type is specified in Types.swift and selected
    /// via build settings
    // maybe make this thread local
    public static var platform = PlatformType()
    
    //--------------------------------------------------------------------------
    /// the Platform log writing object
    @inlinable public static var log: Log {
        get { logWriter }
        set { logWriter = newValue }
    }
    /// a counter used to uniquely identify queue events for diagnostics
    @inlinable static var nextQueueEventId: Int {
        queueEventCounter += 1
        return queueEventCounter
    }
    
    /// nextBufferId
    @inlinable public static var nextBufferId: Int {
        bufferIdCounter += 1
        return bufferIdCounter
    }
    /// the currently active queue that platform functions will use
    /// - Returns: the current device queue
    @inlinable
    public static var currentQueue: DeviceQueue {
        Context.platform.currentQueue
    }

    //--------------------------------------------------------------------------
    /// a convenience property. `true` if the context is inferring
    @inlinable
    public static var isInferring: Bool {
        Context.evaluationModeStack.last! == .inferring
    }

    /// a convenience property. `true` if the context is training
    @inlinable
    public static var isTraining: Bool {
        Context.evaluationModeStack.last! == .training
    }

    @inlinable
    public static func whileInferring<R>(_ body: () throws -> R) rethrows -> R {
        Context.evaluationModeStack.append(.inferring)
        defer { _ = Context.evaluationModeStack.popLast() }
        return try body()
    }

    @inlinable
    public static func whileTraining<R>(_ body: () throws -> R) rethrows -> R {
        Context.evaluationModeStack.append(.training)
        defer { _ = Context.evaluationModeStack.popLast() }
        return try body()
    }

    //--------------------------------------------------------------------------
    /// randomSeed
    /// - Note: Whenever obtained, the random seed is also updated so that
    /// future stateless random TensorFlow op executions will result
    /// in non-deterministic results.
    @inlinable
    public var randomSeed: RandomSeed {
        mutating get {
            let seed = _randomSeed
            _randomSeed = (seed.0, seed.1 + 1)
            return seed
        }
        set { _randomSeed = newValue }
    }
    
    @usableFromInline
    var _randomSeed: RandomSeed = generateRandomSeed()

    /// The random number generator.
    @usableFromInline
    var randomNumberGenerator = AnyRandomNumberGenerator(
        PhiloxRandomNumberGenerator(uint64Seed: UInt64(time(nil))))

//
//    //--------------------------------------------------------------------------
//    /// returns the thread local instance of the queues stack
//    @usableFromInline
//    static var threadLocal: Platform {
//        // try to get an existing state
//        if let state = pthread_getspecific(key) {
//            return Unmanaged.fromOpaque(state).takeUnretainedValue()
//        } else {
//            // create and return new state
//            let state = Platform()
//            pthread_setspecific(key, Unmanaged.passRetained(state).toOpaque())
//            return state
//        }
//    }
//
//    //--------------------------------------------------------------------------
//    /// thread data key
//    @usableFromInline
//    static let key: pthread_key_t = {
//        var key = pthread_key_t()
//        pthread_key_create(&key) {
//            #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
//            let _: AnyObject = Unmanaged.fromOpaque($0).takeRetainedValue()
//            #else
//            let _: AnyObject = Unmanaged.fromOpaque($0!).takeRetainedValue()
//            #endif
//        }
//        return key
//    }()
}

//==============================================================================
public enum EvaluationMode {
    /// operation is used to perform inference
    case inferring
    /// operation is used to perform training
    case training
}

//==============================================================================
/// ServiceDevice
/// a compute device represents a physical service device installed
/// on the platform
public protocol ServiceDevice: class, Logger {
    /// the id of the device for example dev:0, dev:1, ...
    var id: Int { get }
    /// name used logging
    var name: String { get }
    /// a collection of device queues for scheduling work
    var queues: [DeviceQueue] { get }
    /// specifies the type of device memory for data transfer
    var memoryType: MemoryType { get }
}

//==============================================================================
/// DeviceMemory
public struct DeviceMemory {
    /// base address and size of buffer
    public let buffer: UnsafeMutableRawBufferPointer
    /// function to free the memory
    public let deallocate: () -> Void
    /// specifies the device memory type for data transfer
    public let memoryType: MemoryType
    /// version
    public var version: Int
    
    @inlinable
    public init(buffer: UnsafeMutableRawBufferPointer,
                memoryType: MemoryType,
                _ deallocate: @escaping () -> Void)
    {
        self.buffer = buffer
        self.memoryType = memoryType
        self.version = -1
        self.deallocate = deallocate
    }
}

//==============================================================================
/// QueueEvent
/// A queue event is a barrier synchronization object that is
/// - created by a `DeviceQueue`
/// - recorded on a queue to create a barrier
/// - waited on by one or more threads for group synchronization
public protocol QueueEvent {
    /// the id of the event for diagnostics
    var id: Int { get }
    /// is `true` if the even has occurred, used for polling
    var occurred: Bool { get }
    /// the last time the event was recorded
    var recordedTime: Date? { get set }

    /// measure elapsed time since another event
    func elapsedTime(since other: QueueEvent) -> TimeInterval?
    /// will block the caller until the timeout has elapsed if one
    /// was specified during init, otherwise it will block forever
    func wait() throws
}

//==============================================================================
public extension QueueEvent {
    /// elapsedTime
    /// computes the timeinterval between two queue event recorded times
    /// - Parameter other: the other event used to compute the interval
    /// - Returns: the elapsed interval. Will return `nil` if this event or
    ///   the other have not been recorded.
    @inlinable
    func elapsedTime(since other: QueueEvent) -> TimeInterval? {
        guard let time = recordedTime,
            let other = other.recordedTime else { return nil }
        return time.timeIntervalSince(other)
    }
}

//==============================================================================
/// QueueEventOptions
public struct QueueEventOptions: OptionSet {
    public let rawValue: Int
    public static let timing       = QueueEventOptions(rawValue: 1 << 0)
    public static let interprocess = QueueEventOptions(rawValue: 1 << 1)
    
    @inlinable
    public init() { self.rawValue = 0 }
    
    @inlinable
    public init(rawValue: Int) { self.rawValue = rawValue }
}

public enum QueueEventError: Error {
    case timedOut
}

//==============================================================================
/// MemoryType
public enum MemoryType {
    case unified, discreet
}

//==============================================================================
/// QueueId
/// a unique service device queue identifier that is used to index
/// through the service device tree for directing workflow
public struct QueueId {
    public let device: Int
    public let queue: Int
    
    @inlinable
    public init(_ device: Int, _ queue: Int) {
        self.device = device
        self.queue = queue
    }
}

//==============================================================================
// assert messages
@usableFromInline
let _messageQueueThreadViolation =
"a queue can only be accessed by the thread that created it"

//==============================================================================
/// DeviceError
public enum DeviceError : Error {
    case initializeFailed
    case queueError(idPath: [Int], message: String)
    case timeout(idPath: [Int], message: String)
}
