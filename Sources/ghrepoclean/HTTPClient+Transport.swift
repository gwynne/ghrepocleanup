import AsyncHTTPClient
import NIO
import NIOHTTP1
import NetworkClient
import Foundation

public typealias NetworkClientResponse = Response

extension HTTPClient: Transport {
    public func send(request: URLRequest, completion: @escaping (NetworkClientResponse) -> Void) {
        var httpRequest: Request
        do {
            httpRequest = try HTTPClient.Request(
                url: request.url!,
                method: .init(rawValue: request.httpMethod!),
                headers: request.allHTTPHeaderFields.map { .init($0.map { $0 }) } ?? [:],
                body: request.httpBody.map { .data($0) }
            )
            if !httpRequest.headers.contains(name: "User-Agent") {
                httpRequest.headers.replaceOrAdd(name: "User-Agent", value: "AsyncHTTPClient/1.x (via NetworkClient/0.x)")
            }
        } catch {
            return completion(.error(.unknown(error)))
        }
        
        self.execute(request: httpRequest).whenComplete { switch $0 {
            case .success(let response):
                guard 200 ..< 300 ~= response.status.code else {
                    if let status = APIError.Status(code: Int(response.status.code)) {
                        return completion(.failure(status: status, body: response.body.map { Data($0.readableBytesView) } ?? Data()))
                    } else {
                        return completion(.error(.network(.init(.cannotParseResponse))))
                    }
                }
                return completion(.success(response.body.map { Data($0.readableBytesView) } ?? Data()))
            case .failure(let error):
                return completion(.error(.unknown(error)))
        } }
    }
}

public final class AuthorizationProvider: Transport {
    
    /// The base `Transport` which will be used to perform the actual send.
    private let base: Transport
    
    /// The "encoded" form of the credentials (if supplied) which will be added to each request. To reduce the potential
    /// of exfiltation of credentials from active memory, the original credentials are never stored by this provider,
    /// though in the case of HTTP Basic authentication the point may be considered somewhat moot (Base64 does not even
    /// represent obfuscation, much less encryption or hashing).
    private var encodedAuthorizationHeader: String?
    
    /// An optional callback to be invoked upon receipt of a 401 Unauthorized response; if the callback returns a set of
    /// credentials, the request will automatically be retried with the new authorization. The callback is provided with
    /// the response the server sent to the failed request. If the callback is `nil`, or returns `nil`, the 401 response
    /// is considered final and returned as the final result of the request.
    ///
    /// - Important: If a callback returns new credentials, those credentials then become current and are reused by the
    ///   provider to authorize subsequent requests, _even if authorization using those credentials subsequently fails_.
    ///   There is currently no way to prevent this behavior except by returning `nil` from a later invocation of the
    ///   callback.
    ///
    /// - Warning: A 401 response does _not_ result in the provider erasing its cached authorization. However, the
    ///   cached authorization _is_ erased if the callback returns `nil`.
    ///
    /// - Note: The provider makes no attempt to prevent a client from getting itself into an infinite fail/retry loop
    ///   by (for example) unconditionally returning the same non-`nil` credentials over and over.
    private let requestNewCredentialsCallback: ((Response) -> HTTPClient.Authorization?)?
    
    /// Create a new authorization provider.
    ///
    /// - Parameters:
    ///   - base: The underlying transport the provider is extending.
    ///   - initialAuthorization: An optional set of credentials to be sent with every request. If no initial
    ///     credentials are supplied, the authorization header is not set in requests until and unless the credentials
    ///     callback returns a non-`nil` result.
    ///   - newCredentialsCallback: An optional callback to be invoked whenever a server responds to a request with the
    ///     401 Unauthorized status code. See `requestNewCredentialsCallback` for details.
    ///
    /// - Note: If neither an initial authorization nor a credentials callback are provided, the authorization provider
    ///   will have no effect on requests whatsoever. Fixing this flaw in the API surface would require multiple
    ///   nearly-identical initializers and probably isn't worth it.
    ///
    /// - Warning: If an `Authorization` header is already set on an incoming `Request`, the authorization provider will
    ///   _not_ overwrite it. However, if the server replies to such a request with a 401 status and a credentials
    ///   callback returns new credentials, those new credentials will then overwrite the original authorization for the
    ///   retried request.
    public init(
        base: Transport,
        initialAuthorization: HTTPClient.Authorization? = nil,
        newCredentialsCallback: ((Response) -> HTTPClient.Authorization?)? = nil
    ) {
        self.base = base
        self.encodedAuthorizationHeader = initialAuthorization?.headerValue
        self.requestNewCredentialsCallback = newCredentialsCallback
    }
    
    /// See `Transport.send(request:completion:)`.
    ///
    /// - Important: Authorization retries reuse the same `URLRequest` that was provided as input. Requests using
    ///   `httpBodyStream` will probably not work very well in this case.
    public func send(request: URLRequest, completion: @escaping (Response) -> Void) {
        var finalRequest: URLRequest
        
        if let authorizationHeader = self.encodedAuthorizationHeader,
           request.value(forHTTPHeaderField: "Authorization") == nil
       {
            var newRequest = request
            newRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
            finalRequest = newRequest
        } else {
            finalRequest = request
        }
        
        base.send(request: finalRequest, completion: { response in
            if case .failure(.unauthorized, _) = response, let callback = self.requestNewCredentialsCallback {
                self.encodedAuthorizationHeader = callback(response)?.headerValue
                if self.encodedAuthorizationHeader != nil {
                    finalRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                    return self.send(request: finalRequest, completion: completion)
                }
            }
            return completion(response)
        })
    }
}
