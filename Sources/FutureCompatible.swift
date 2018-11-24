// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).
import Foundation

/// Future extenions.
public struct FutureExtension<Base> {
    /// Base object to extend.
    public let base: Base

    /// Creates extensions with base object.
    public init(_ base: Base) {
        self.base = base
    }
}

/// A type that has future extensions.
///
/// - note: In order to add `fx` to a protocol implement `fx` property manually.
public protocol FutureCompatible {
    associatedtype CompatibleType
    static var fx: FutureExtension<CompatibleType>.Type { get set }
    var fx: FutureExtension<CompatibleType> { get set }
}

extension FutureCompatible {
    /// Future extensions.
    public static var fx: FutureExtension<Self>.Type {
        get { return FutureExtension<Self>.self }
        set { /* Enabled mutation */ }
    }

    /// Future extensions.
    public var fx: FutureExtension<Self> {
        get { return FutureExtension(self) }
        set { /* Enabled mutation */ }
    }
}

import class Foundation.NSObject

/// Extend NSObject with `fx` proxy.
extension NSObject: FutureCompatible { }
