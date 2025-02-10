//
//  SignalsNetworkTracking.swift
//  Shopify
//
//  Created by Brandon Sneed on 9/29/22.
//

import Foundation
import Segment

class SignalsNetworkTracking: UtilityPlugin {
    let key: String = "SignalsNetworkTrackingPlugin"
    
    func configure(analytics: Analytics) {
        self.analytics = analytics
    }
    
    let type = PluginType.utility
    weak var analytics: Analytics? = nil
    
    init() {
        setupNetworkHook()
    }

    internal func setupNetworkHook() {
        URLProtocol.registerClass(SignalsNetworkProtocol.self)
    }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        // do nothing.
        return event
    }
}

public class SignalsNetworkProtocol: URLProtocol, URLSessionDataDelegate {
    static internal var allowedHosts = [String]()
    static internal var blockedHosts = [String]()
    
    internal var session: URLSession? = nil
    internal var sessionTask: URLSessionDataTask? = nil
    @Atomic internal var receivedData: Data? = nil
    @Atomic internal var response: URLResponse? = nil
    
    internal static var signalFlag = "Signaling"
    
    override public init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override public class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host() else { return false }
        if Self.blockedHosts.contains(host) {
            return false
        } else if Self.allowedHosts.contains(host) || Self.allowedHosts.contains(SignalsConfiguration.allowAllHosts) {
            guard request.url?.scheme == "http" || request.url?.scheme == "https" else { return false }
            if property(forKey: Self.signalFlag, in: request) != nil {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    override public func startLoading() {
        guard let newRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        Self.setProperty(true, forKey: Self.signalFlag, in: newRequest)
        
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        sessionTask = session?.dataTask(with: newRequest as URLRequest)
        sessionTask?.resume()
        
        // emit our request signal since it's about to go out.
        emit(action: .request)
    }
    
    override public func stopLoading() {
        sessionTask?.cancel()
        session?.invalidateAndCancel()
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        _receivedData.mutate { rd in
            if rd == nil { rd = Data() }
            rd?.append(data)
        }
    }
        
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
            
        if let response = task.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self._response.set(response)
        }
        
        client?.urlProtocolDidFinishLoading(self)
        emit(action: .response)
    }
    
}

extension SignalsNetworkProtocol {
    public typealias BodyDeserializer = (Data?) -> [String: Any]?
    
    public static var deserializers = [
        "application/json": applicationJSON,
        "text/plain": textPlain
    ]
    
    public static var textPlain: BodyDeserializer = { body in
        guard let body else { return nil }
        guard let str = String(data: body, encoding: .utf8) else { return nil }
        return ["body": str]
    }
    
    public static var applicationJSON: BodyDeserializer = { body in
        guard let body else { return nil }
        if let result = try? JSONSerialization.jsonObject(with: body) {
            return ["content": result]
        }
        return nil
    }
    
    public static func addDeserializer(for contentType: String, deserializer: @escaping BodyDeserializer) {
        deserializers[contentType] = deserializer
    }
}

extension SignalsNetworkProtocol {
    func deserialize(contentType: String?) -> [String: Any]? {
        guard let contentType else { return nil }
        let parts = contentType.components(separatedBy: ";")
        // strip any params off .. we can't really evaluate them that well
        // ie: "text/plain;charset=UTF-8" becomes "text/plain"
        guard let ct = parts.first else { return nil }
        let deserializer = Self.deserializers[ct] ?? Self.deserializers[contentType] ?? Self.textPlain
        return deserializer(receivedData)
    }
    
    func emit(action: NetworkSignal.NetworkAction) {
        guard let url = request.url else { return }
        let httpResponse = self.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode
        
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
        let data = deserialize(contentType: contentType)
        
        let s = NetworkSignal(action: action, url: url, statusCode: statusCode, data: data)
        Signals.shared.emit(signal: s, source: .autoNetwork)
    }
}

final class SignalsAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    typealias CustomAuthenticationChallengeHandler = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    let handler: CustomAuthenticationChallengeHandler
    
    init(handler: @escaping CustomAuthenticationChallengeHandler) {
        self.handler = handler
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        handler(.useCredential, credential)
    }
    
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        handler(.useCredential, nil)
    }
    
    func cancel(_ challenge: URLAuthenticationChallenge) {
        handler(.cancelAuthenticationChallenge, nil)
    }
    
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        handler(.performDefaultHandling, nil)
    }
    
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        handler(.rejectProtectionSpace, nil)
    }
}
