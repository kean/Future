// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

public struct FutureExtension<Base> {
    /// Base object to extend.
    public let base: Base

    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    public init(_ base: Base) {
        self.base = base
    }
}

/// A type that has future extensions.
public protocol FutureCompatible {
    /// Extended type
    associatedtype CompatibleType

    /// Reactive extensions.
    static var fx: FutureExtension<CompatibleType>.Type { get set }

    /// Reactive extensions.
    var fx: FutureExtension<CompatibleType> { get set }
}

extension FutureCompatible {
    /// Future extensions.
    public static var fx: FutureExtension<Self>.Type {
        get {
            return FutureExtension<Self>.self
        }
        set {
            // this enables using FutureX to "mutate" base type
        }
    }

    /// Future extensions.
    public var fx: FutureExtension<Self> {
        get {
            return FutureExtension(self)
        }
        set {
            // this enables using Reactive to "mutate" base object
        }
    }
}

import class Foundation.NSObject

/// Extend NSObject with `fx` proxy.
extension NSObject: FutureCompatible { }
