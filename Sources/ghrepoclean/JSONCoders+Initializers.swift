import Foundation

extension JSONEncoder {
    /// Convenience initializer for specifying encoding strategies on a `JSONEncoder`.
    /// Allows specifying `.withoutEscapingSlashes` without having to deal with availability checks.
    public convenience init(
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
        dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
        nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
        prettyPrint: Bool = false,
        sortKeys: Bool = false,
        withoutEscapingSlashes: Bool = false,
        userInfo: [CodingUserInfoKey: Any] = [:]
    ) {
        self.init()
        self.dateEncodingStrategy = dateEncodingStrategy
        self.dataEncodingStrategy = dataEncodingStrategy
        self.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
        self.keyEncodingStrategy = keyEncodingStrategy
        if prettyPrint {
            self.outputFormatting.insert(.prettyPrinted)
        }
        if sortKeys {
            self.outputFormatting.insert(.sortedKeys)
        }
        if withoutEscapingSlashes {
            // The fix for this missing functionality didn't make it into Swift 5.3 for whatever reason, but it appears
            // that it will get into 5.3.1.
            #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || swift(>=5.3.1)
            if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
                self.outputFormatting.insert(.withoutEscapingSlashes)
            }
            #endif
        }
        self.userInfo = userInfo
    }
}

extension JSONDecoder {
    /// Convenience initializer for specifying decoding strategies on a `JSONDecoder`.
    public convenience init(
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
        nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        userInfo: [CodingUserInfoKey: Any] = [:]
    ) {
        self.init()
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        self.keyDecodingStrategy = keyDecodingStrategy
        self.userInfo = userInfo
    }
    
    /// A version of `decode(_:from:)` which enables inferring the decoded type from context.
    public func decode<T>(data: Data, as type: T.Type = T.self) throws -> T where T: Decodable {
        return try self.decode(T.self, from: data)
    }
}
