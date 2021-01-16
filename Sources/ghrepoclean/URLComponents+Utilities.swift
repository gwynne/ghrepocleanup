import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Optional where Wrapped == URLQueryItem {

    /// Trivial forwarding initializer for `URLQueryItem.init?(name:requiredValue:)` so that
    /// `.init(name:requiredValue:)` (rather than explicitly naming `URLQueryItem`) is not ambiguous.
    public init<Value: LosslessStringConvertible>(name: String, requiredValue: Value?) {
        self = Wrapped.init(name: name, requiredValue: requiredValue)
    }

}

extension URL {

    /// Shorthand for `URLComponents.init(url: self, resolvingAgainstBaseURL: true)`
    public var components: URLComponents? { URLComponents(url: self, resolvingAgainstBaseURL: true) }
    
    /// Shorthand for `URLComponents.init(url: self).setQueryItems(queryItems).url`. Replaces any existing query string.
    /// Semantics are identical to those of `URLComponents.setQueryItems(_:)`.
    public func withQuery(items: URLQueryItem?...) -> Self? { self.withQuery(items: items) }
    
    /// Array version of `URL.withQuery(items:)`.
    public func withQuery(items: [URLQueryItem?]) -> Self? {
        var components = self.components
        components?.setQueryItems(items)
        return components?.url
    }
    
}

extension URLComponents {
    
    // MARK: - Initializers
    
    /// Shorthand initializer which assumes `true` for `resolvingAgainstBaseURL`.
    public init?(_ url: URL) { self.init(url: url, resolvingAgainstBaseURL: true) }

    // MARK: - Path components

    /// The `path` component, represented as an array of individual path components as per `URL.pathComponents`.
    public var pathComponents: [String] {
        get {
            // If this `URLComponents` object is being built from scratch, it may not be complete enough yet for
            // `self.url` to yield something valid; create a phantom file URL to access URL's path management logic
            // instead. This is efficient, but it's not clear what a better alternative would be.
            return self.path.isEmpty ? [] : URL(fileURLWithPath: self.path, isDirectory: false).pathComponents
        }
        set {
            self.path = newValue.reduce(URL(fileURLWithPath: "/", isDirectory: true)) {
                $0.appendingPathComponent($1, isDirectory: false)
            }.path
        }
    }
    
    /// The `percentEncodedPath` component, represented as an array of individual path components as per
    /// `URL.pathComponents`.
    public var percentEncodedPathComponents: [String] {
        get {
            return self.percentEncodedPath.isEmpty ? [] : URL(fileURLWithPath: self.percentEncodedPath, isDirectory: false).pathComponents
        }
        set {
            self.percentEncodedPath = newValue.reduce(URL(fileURLWithPath: "/", isDirectory: true)) {
                $0.appendingPathComponent($1, isDirectory: false)
            }.path
        }
    }
    
    /// Append one or more path components to the current `path`, as per `URL.appendPathComponent(_:)`.
    public mutating func appendPathComponents<S: StringProtocol>(_ components: S...) {
        self.appendPathComponents(components)
    }

    /// Append zero or more path components to the current `path`, as per `URL.appendPathComponent(_:)`.
    public mutating func appendPathComponents<S: StringProtocol>(_ components: [S]) {
        self.pathComponents = self.pathComponents + components.map(String.init(_:))
    }

    /// Append one or more percent-encoded path components to the current `percentEncodedPath`, as per
    /// `URL.appendPathComponent(_:)`.
    public mutating func appendPercentEncodedPathComponents<S: StringProtocol>(_ components: S...) {
        self.appendPercentEncodedPathComponents(components)
    }

    /// Append zero or more percent-encoded path components to the current `percentEncodedPath`, as per
    /// `URL.appendPathComponent(_:)`.
    public mutating func appendPercentEncodedPathComponents<S: StringProtocol>(_ components: [S]) {
        self.percentEncodedPathComponents = self.percentEncodedPathComponents + components.map(String.init(_:))
    }
    
    // MARK: - Query items
    
    /// Add one or more specified URL query items to the existing set of query items, ignoring `nil` inputs. This method
    /// is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func addQueryItems(_ items: URLQueryItem?...) {
        self.addQueryItems(items)
    }

    /// Add zero or more specified URL query items to the existing set of query items, ignoring `nil` inputs. This
    /// method is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func addQueryItems(_ items: [URLQueryItem?]) {
        self.queryItems = (self.queryItems ?? []) + items.compactMap { $0 }
    }

    /// Replace the current set of URL query items with one or more specified items, ignoring `nil` inputs. This method
    /// is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func setQueryItems(_ items: URLQueryItem?...) {
        self.setQueryItems(items)
    }

    /// Replace the current set of URL query items with zero or more specified items, ignoring `nil` inputs. This method
    /// is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func setQueryItems(_ items: [URLQueryItem?]) {
        self.queryItems = items.compactMap { $0 }
    }

    /// Add one or more specified percent-encoded URL query items to the existing set of query items, ignoring `nil`
    /// inputs. This method is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func addPercentEncodedQueryItems(_ items: URLQueryItem?...) {
        self.addPercentEncodedQueryItems(items)
    }

    /// Add zero or more specified percent-encoded URL query items to the existing set of query items, ignoring `nil`
    /// inputs. This method is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func addPercentEncodedQueryItems(_ items: [URLQueryItem?]) {
        self.percentEncodedQueryItems = (self.percentEncodedQueryItems ?? []) + items.compactMap { $0 }
    }

    /// Replace the current set of URL query items with one or more specified percent-encoded items, ignoring `nil`
    /// inputs. This method is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func setPercentEncodedQueryItems(_ items: URLQueryItem?...) {
        self.setPercentEncodedQueryItems(items)
    }

    /// Replace the current set of URL query items with zero or more specified percent-encoded items, ignoring `nil`
    /// inputs. This method is designed to interoperate with the `URLQueryItems.init?(name:requiredValue:)` initializer.
    public mutating func setPercentEncodedQueryItems(_ items: [URLQueryItem?]) {
        self.percentEncodedQueryItems = items.compactMap { $0 }
    }

}

extension URLQueryItem {
    
    /// An alternate initializer for `URLQueryItem` which will fail with `nil` rather than initializing an item if the
    /// provided value is `nil`. This behavior is intended to simplify construction of queries with
    /// potentially-unspecified inputs, such as "only specify a sort key if one was provided". The value may be anything
    /// that can be losslessly represented as a `String`.
    public init?<Value: LosslessStringConvertible>(name: String, requiredValue: Value?) {
        guard let value = requiredValue else {
            return nil
        }
        self.init(name: name, value: value.description)
    }
}

extension URLRequest {
    
    /// Like `URLRequest.init(url:cachePolicy:timeoutInterval:)` but allows additionally specifying one or more HTTP
    /// header name/value pairs. Header values are set with `URLRequest.setValue(_:forHTTPHeaderField:)`.
    public init(
        url: URL,
        additionalHTTPHeaders: [String: String] = [:],
        method: String? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60.0
    ) {
        self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        for (name, value) in additionalHTTPHeaders {
            self.setValue(value, forHTTPHeaderField: name)
        }
        self.httpMethod = method
    }
}

// MARK: - String to URL

extension String {

    /// Convenience for `URL(fileURLWithPath:isDirectory:)`. This accessor should not be used if the path refers to a directory, but is
    /// preferable to `.asDirectoryURL` if it isn't known which is correct.
    public var asFileURL: URL {
        return URL(fileURLWithPath: self, isDirectory: false)
    }
    
    /// Convenience for `URL(fileURLWithPath:isDirectory:)`. This accessor must not be used if the path refers to a file. If you don't
    /// know whether or not it refers to a directory, use `.asFileURL` instead.
    public var asDirectoryURL: URL {
        return URL(fileURLWithPath: self, isDirectory: true)
    }

}

// MARK: - URL conveniences
extension URL {

    // MARK: - URL.append[ing]PathComponent(StringProtocol[, isDirectory])

    /// Convenience for invoking `appendingPathComponent()` with a `Substring`, but expressed as conformance to `StringProtocol` so
    /// it will correctly resolve for the sequence-handling variants below. The compiler should continue to resolve invocations that
    /// pass a `String` concretely to the existing, more specialized method.
    public func appendingPathComponent<S>(_ component: S) -> URL where S: StringProtocol {
        return self.appendingPathComponent(String(component))
    }

    /// Convenience for invoking `appendingPathComponent()` with a `Substring`, `isDirectory`-aware variant.
    public func appendingPathComponent<S>(_ component: S, isDirectory: Bool) -> URL where S: StringProtocol {
        return self.appendingPathComponent(String(component), isDirectory: isDirectory)
    }

    /// Convenience for invoking `appendPathComponent()` with a `Substring`, mutating variant.
    public mutating func appendPathComponent<S>(_ component: S) where S: StringProtocol {
        self.appendPathComponent(String(component))
    }

    /// Convenience for invoking `appendPathComponent()` with a `Substring`, mutating `isDirectory`-aware variant.
    public mutating func appendPathComponent<S>(_ component: S, isDirectory: Bool) where S: StringProtocol {
        self.appendPathComponent(String(component), isDirectory: isDirectory)
    }

    // MARK: - URL.checkAbsolutePathWasRecentlyPresent()

    /// Convenience for using `checkResourceIsReachable()` as a "does path exist on disk" check, with the usual attendant caveats of such a check.
    /// - Warning: The name of this method is chosen specifically to underscore that its result can only considered up-to-date until immediately
    ///   before the method returns, as with any snapshot of shared mutable state. "Recently present" means "was present at the exact time that
    ///   the check was performed and not necesarily any other prior or later time". It does _NOT_ indicate any ability to track the previous state
    ///   of a path's existence.
    /// - Note: Asserts on non-file URLs.
    /// - Returns: `true` if the path was present at the time of the check, `false` if not _and_ no other error occurred.
    /// - Throws: Any error that occurs _other_ than `ENOENT`.
    public func checkAbsolutePathWasRecentlyPresent() throws -> Bool {
        assert(self.isFileURL)
        
        do {
            return try self.checkResourceIsReachable()
        } catch let error as CocoaError {
            if error.code == .fileReadNoSuchFile {
                return false
            }
            throw error
        }
    }
}

// MARK: - URL shorthand
extension URL {
    
    // MARK: - URL.[re]type[d](as: [StringProtocol])
    
    /// Construct a `URL` by appending one or more path extensions to another `URL`.
    public func typed<S>(as specifiers: S...) -> URL where S: StringProtocol {
        return self.typed(as: specifiers)
    }
    
    /// Construct a `URL` by appending an arbitrary number of path extensions to another `URL`.
    public func typed<S>(as specifiers: [S]) -> URL where S: StringProtocol {
        return specifiers.reduce(self) { $0.appendingPathExtension(String($1)) }
    }
    
    /// Append one or more path extensions to a `URL`.
    public mutating func type<S>(as specifiers: S...) where S: StringProtocol {
        self.type(as: specifiers)
    }
    
    /// Append an arbitrary number of path extensions to a `URL`.
    public mutating func type<S>(as specifiers: [S]) where S: StringProtocol {
        specifiers.forEach { self.appendPathExtension(String($0)) }
    }
    
    /// Construct a `URL` by deleting up to one existing path extension from another `URL`, then appending one or more
    /// new path extensions.
    public func retyped<S>(as specifiers: S...) -> URL where S: StringProtocol {
        return self.retyped(as: specifiers)
    }
    
    /// Construct a `URL` by deleting up to one existing path extension from another `URL`, then appending an arbitrary
    /// number of new path extensions.
    public func retyped<S>(as specifiers: [S]) -> URL where S: StringProtocol {
        return self.deletingPathExtension().typed(as: specifiers)
    }
    
    /// Delete up to one existing path extension from a `URL`, then append one or more new path extensions.
    public mutating func retype<S>(as specifiers: S...) where S: StringProtocol {
        self.retype(as: specifiers)
    }
    
    /// Delete up to one existing path extension from a `URL`, then append an arbitrary number of new path extensions.
    public mutating func retype<S>(as specifiers: [S]) where S: StringProtocol {
        self.deletePathExtension()
        specifiers.forEach { self.appendPathExtension(String($0)) }
    }
    
    
    // MARK: - URL.identif[y|ing](StringProtocol[, specifiers])
    
    /// Construct a `URL` by appending a filename component to another `URL`.
    public func identifying<S>(_ filename: S) -> URL where S: StringProtocol {
        return self.appendingPathComponent(filename, isDirectory: false)
    }

    /// Construct a `URL` by appending a filename component and an arbitrary number of path extensions to a `URL`.
    public func identifying<S1, S2>(_ filename: S1, as specifiers: S2...) -> URL where S1: StringProtocol, S2: StringProtocol {
        return self.identifying(filename, as: specifiers)
    }
    
    /// Construct a `URL` by appending a filename component and an array of path extensions to a `URL`.
    public func identifying<S1, S2>(_ filename: S1, as specifiers: [S2]) -> URL where S1: StringProtocol, S2: StringProtocol {
        return specifiers.reduce(self.appendingPathComponent(filename, isDirectory: false)) { $0.appendingPathExtension(String($1)) }
    }
    
    /// Append a filename component to a `URL`.
    public mutating func identify<S>(_ filename: S) where S: StringProtocol {
        self.appendPathComponent(filename, isDirectory: false)
    }

    /// Append a filename component and an arbitrary number of path extensions to a `URL`.
    public mutating func identify<S1, S2>(_ filename: S1, as specifiers: S2...) where S1: StringProtocol, S2: StringProtocol {
        self.identify(filename, as: specifiers)
    }

    /// Append a filename component and an array of path extensions to a `URL`.
    public mutating func identify<S1, S2>(_ filename: S1, as specifiers: [S2]) where S1: StringProtocol, S2: StringProtocol {
        self.appendPathComponent(filename, isDirectory: false)
        specifiers.forEach { self.appendPathExtension(String($0)) }
    }
    
    // MARK: - URL.descend[ing](into: StringProtocol)

    /// Construct a `URL` by appending a subdirectory component to another `URL`.
    public func descending<S>(into subdirectory: S) -> URL where S: StringProtocol {
        return self.appendingPathComponent(subdirectory, isDirectory: true)
    }
    
    /// Append a subdirectory component to a `URL`.
    public mutating func descend<S>(into subdirectory: S) where S: StringProtocol {
        self.appendPathComponent(subdirectory, isDirectory: true)
    }
    
    // MARK: - URL.travers[e|ing](StringProtocol...)

    /// Construct a URL by appending an arbitrary number of subdirectory components to another `URL`.
    public func traversing<S>(_ subdirs: S...) -> URL where S: StringProtocol {
        return self.traversing(subdirs)
    }
    
    /// Construct a URL by appending an array of subdirectory components to another `URL`.
    public func traversing<S>(_ subdirs: [S]) -> URL where S: StringProtocol {
        return subdirs.reduce(self) { $0.descending(into: $1) }
    }

    /// Append an arbitrary number of subdirectory components to a `URL`.
    public mutating func traverse<S>(_ subdirs: S...) where S: StringProtocol {
        self.traverse(subdirs)
    }
    
    /// Append an array of subdirectory components to a `URL`.
    public mutating func traverse<S>(_ subdirs: [S]) where S: StringProtocol {
        subdirs.forEach { self.descend(into: $0) }
    }
    
    // MARK: - URL.travers[e|ing](StringProtocol..., for: StringProtocol)

    /// Construct a URL by appending an arbitrary number of subdirectory components and a filename component to another `URL`.
    public func traversing<S1, S2>(_ subdirs: S1..., for filename: S2) -> URL where S1: StringProtocol, S2: StringProtocol {
        return self.traversing(subdirs, for: filename)
    }
    
    /// Construct a URL by appending an array of subdirectory components and a filename component to another `URL`.
    public func traversing<S1, S2>(_ subdirs: [S1], for filename: S2) -> URL where S1: StringProtocol, S2: StringProtocol {
        return subdirs.reduce(self) { $0.descending(into: $1) }.identifying(filename)
    }
    
    
    /// Append an arbitrary number of subdirectory components and a filename component to a `URL`.
    public mutating func traverse<S1, S2>(_ subdirs: S1..., for filename: S2) where S1: StringProtocol, S2: StringProtocol {
        self.traverse(subdirs, for: filename)
    }
    
    /// Append an array of subdirectory components and a filename component to a `URL`.
    public mutating func traverse<S1, S2>(_ subdirs: [S1], for filename: S2) where S1: StringProtocol, S2: StringProtocol {
        subdirs.forEach { self.descend(into: $0) }
        self.identify(filename)
    }
    
    // MARK: - URL.travers[e|ing](StringProtocol..., for: StringProtocol, as: StringProtocol|Array<StringProtocol>)

    /// Construct a URL by appending an arbitrary number of subdirectory components, a filename component, and a path extension to another `URL`.
    public func traversing<S1, S2, S3>(_ subdirs: S1..., for filename: S2, as specifier: S3) -> URL where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        return self.traversing(subdirs, for: filename, as: specifier)
    }

    /// Construct a URL by appending an arbitrary number of subdirectory components, a filename component, and an array of path extensions to another `URL`.
    public func traversing<S1, S2, S3>(_ subdirs: S1..., for filename: S2, as specifiers: [S3]) -> URL where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        return self.traversing(subdirs, for: filename, as: specifiers)
    }

    /// Construct a URL by appending an array of subdirectory components, a filename component, and a path extension to another `URL`.
    public func traversing<S1, S2, S3>(_ subdirs: [S1], for filename: S2, as specifier: S3) -> URL where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        return self.traversing(subdirs, for: filename, as: [specifier])
    }

    /// Construct a URL by appending an array of subdirectory components, a filename component, and an array of path extensions to another `URL`.
    public func traversing<S1, S2, S3>(_ subdirs: [S1], for filename: S2, as specifiers: [S3]) -> URL where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        return subdirs.reduce(self) { $0.descending(into: $1) }.identifying(filename, as: specifiers)
    }

    /// Append an arbitrary number of subdirectory components, a filename component, and a path extension to a `URL`.
    public mutating func traverse<S1, S2, S3>(_ subdirs: S1..., for filename: S2, as specifier: S3) where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        self.traverse(subdirs, for: filename, as: specifier)
    }

    /// Append an arbitrary number of subdirectory components, a filename component, and an array of path extensions to a `URL`.
    public mutating func traverse<S1, S2, S3>(_ subdirs: S1..., for filename: S2, as specifiers: [S3]) where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        self.traverse(subdirs, for: filename, as: specifiers)
    }

    /// Append an array of subdirectory components, a filename component, and a path extension to a `URL`.
    public mutating func traverse<S1, S2, S3>(_ subdirs: [S1], for filename: S2, as specifier: S3) where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        self.traverse(subdirs, for: filename, as: [specifier])
    }

    /// Append an array of subdirectory components, a filename component, and an array of path extensions to a `URL`.
    public mutating func traverse<S1, S2, S3>(_ subdirs: [S1], for filename: S2, as specifiers: [S3]) where S1: StringProtocol, S2: StringProtocol, S3: StringProtocol {
        subdirs.forEach { self.descend(into: $0) }
        self.identify(filename, as: specifiers)
    }
    
    // MARK: - URL.is*URL
    
    /// Invoke `checkAbsolutePathWasRecentlyPresent()` for the URL. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-e` test.
    public var doesExist: Bool {
        (try? self.checkAbsolutePathWasRecentlyPresent()) ?? false
    }
    
    /// Check the URL's `isReadableKey` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-r` test.
    public var isReadableURL: Bool {
        (try? self.resourceValues(forKeys: [.isReadableKey]).isReadable) ?? false
    }
    
    /// Check the URL's `isRegularFileKey` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-f` test.
    public var isRegularFileURL: Bool {
        (try? self.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
    }

    /// Check the URL's `isDirectoryKey` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-d` test.
    public var isDirectoryURL: Bool {
        (try? self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    /// Check the URL's `isExecutableKey` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-x` test.
    public var isExecutableURL: Bool {
        (try? self.resourceValues(forKeys: [.isExecutableKey]).isExecutable) ?? false
    }
    
    /// Check the URL's `isWritableKey` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-w` test.
    public var isWritableURL: Bool {
        (try? self.resourceValues(forKeys: [.isWritableKey]).isWritable) ?? false
    }
    
    /// Check the URL's `isSymbolicLink` resource key. Errors cause `false` to be returned but are otherwise ignored.
    ///
    /// - Note: Loosely corresponds to `bash`'s `-L` test.
    public var isSymbolicLinkURL: Bool {
        (try? self.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }
    
    // MARK: - URL.absoluteResolvedURL
    
    /// Shorthand for `.absoluteURL.resolvingSymlinksInPath()`.
    public var absoluteResolvedURL: URL {
        self.absoluteURL.resolvingSymlinksInPath()
    }
}

