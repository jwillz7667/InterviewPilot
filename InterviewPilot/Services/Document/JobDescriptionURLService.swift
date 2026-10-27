import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A separate ephemeral session per import; no app/provider credentials or cookies are forwarded.
nonisolated struct JobDescriptionURLService: Sendable {
    func importJob(from rawURL: String) async throws -> ImportedJobDescription {
        let url = try JobDescriptionExtractor.validatedURL(from: rawURL)
        let result = try await JobPageFetch().fetch(url)
        try Task.checkCancellation()
        // Parsing runs off the caller's actor so even a large page never blocks audio/UI work.
        let imported = try await Task.detached(priority: .utility) {
            let html: String?
            if result.charset?.lowercased() == "iso-8859-1" || result.charset?.lowercased() == "windows-1252" {
                html = String(data: result.data, encoding: .windowsCP1252)
            } else {
                html = String(data: result.data, encoding: .utf8)
                    ?? String(data: result.data, encoding: .windowsCP1252)
            }
            guard let html else { throw JobDescriptionImportError.unsupportedContent }
            return try JobDescriptionExtractor.extract(html: html, sourceURL: result.url)
        }.value
        try Task.checkCancellation()
        return imported
    }
}

private nonisolated struct JobPageResponse: Sendable {
    let data: Data
    let url: URL
    let charset: String?
}

/// All mutable state is confined to queue; delegate callbacks and cancellation hop onto it.
private nonisolated final class JobPageFetch: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "InterviewPilot.job-import")
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var continuation: CheckedContinuation<JobPageResponse, Error>?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var redirectCount = 0
    private var deadline: DispatchWorkItem?
    private var complete = false
    private var cancellationRequested = false

    func fetch(_ url: URL) async throws -> JobPageResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    self.continuation = continuation
                    guard !self.cancellationRequested else {
                        self.finish(.failure(CancellationError()))
                        return
                    }
                    let deadline = DispatchWorkItem { [weak self] in
                        self?.finish(.failure(JobDescriptionImportError.timedOut))
                    }
                    self.deadline = deadline
                    self.queue.asyncAfter(deadline: .now() + 15, execute: deadline)
                    self.resolvePublicHost(url) { result in
                        guard !self.complete else { return }
                        switch result {
                        case .failure(let error): self.finish(.failure(error))
                        case .success:
                            let configuration = URLSessionConfiguration.ephemeral
                            configuration.timeoutIntervalForRequest = 15
                            configuration.timeoutIntervalForResource = 15
                            configuration.httpCookieStorage = nil
                            configuration.httpShouldSetCookies = false
                            configuration.urlCredentialStorage = nil
                            configuration.urlCache = nil
                            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                            configuration.waitsForConnectivity = false
                            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                            self.session = session
                            let task = session.dataTask(with: Self.request(for: url))
                            self.dataTask = task
                            task.resume()
                        }
                    }
                }
            }
        } onCancel: {
            self.queue.async {
                self.cancellationRequested = true
                if self.continuation != nil { self.finish(.failure(CancellationError())) }
            }
        }
    }

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue("text/html, application/xhtml+xml;q=0.9", forHTTPHeaderField: "Accept")
        return request
    }

    private func finish(_ result: Result<JobPageResponse, Error>) {
        guard !complete else { return }
        complete = true
        deadline?.cancel()
        deadline = nil
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        let waiter = continuation
        continuation = nil
        data.removeAll(keepingCapacity: false)
        waiter?.resume(with: result)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        queue.async {
            guard !self.complete else { completionHandler(.cancel); return }
            guard let response = response as? HTTPURLResponse, let url = response.url,
                  (try? JobDescriptionExtractor.validatedURL(from: url.absoluteString)) != nil else {
                completionHandler(.cancel)
                self.finish(.failure(JobDescriptionImportError.unsafeURL))
                return
            }
            guard (200..<300).contains(response.statusCode) else {
                completionHandler(.cancel)
                self.finish(.failure(JobDescriptionImportError.httpStatus(response.statusCode)))
                return
            }
            guard ["text/html", "application/xhtml+xml"].contains(response.mimeType?.lowercased() ?? "") else {
                completionHandler(.cancel)
                self.finish(.failure(JobDescriptionImportError.unsupportedContent))
                return
            }
            guard response.expectedContentLength <= Int64(JobDescriptionExtractor.maximumPageBytes) else {
                completionHandler(.cancel)
                self.finish(.failure(JobDescriptionImportError.tooLarge))
                return
            }
            self.response = response
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        // Back-pressure this delegate callback instead of retaining an unbounded queue of chunks.
        queue.sync {
            guard !self.complete else { return }
            guard chunk.count <= JobDescriptionExtractor.maximumPageBytes - self.data.count else {
                self.finish(.failure(JobDescriptionImportError.tooLarge))
                return
            }
            self.data.append(chunk)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async {
            guard !self.complete else { return }
            if let error {
                let failure: Error = (error as? URLError)?.code == .timedOut
                    ? JobDescriptionImportError.timedOut : JobDescriptionImportError.networkUnavailable
                self.finish(.failure(failure))
            } else if let response = self.response, let url = response.url {
                self.finish(.success(.init(data: self.data, url: url, charset: response.textEncodingName)))
            } else {
                self.finish(.failure(JobDescriptionImportError.unsupportedContent))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        queue.async {
            guard !self.complete else { completionHandler(nil); return }
            self.redirectCount += 1
            guard self.redirectCount <= 5, let candidate = request.url else {
                completionHandler(nil)
                self.finish(.failure(JobDescriptionImportError.blockedPage))
                return
            }
            let url: URL
            do {
                url = try JobDescriptionExtractor.validatedURL(from: candidate.absoluteString)
                // Never downgrade an HTTPS posting to cleartext through a redirect.
                if response.url?.scheme == "https", url.scheme != "https" {
                    throw JobDescriptionImportError.unsafeURL
                }
            } catch {
                completionHandler(nil)
                self.finish(.failure(error))
                return
            }
            self.resolvePublicHost(url) { result in
                guard !self.complete else { completionHandler(nil); return }
                switch result {
                case .success: completionHandler(Self.request(for: url))
                case .failure(let error):
                    completionHandler(nil)
                    self.finish(.failure(error))
                }
            }
        }
    }

    private func resolvePublicHost(_ url: URL,
                                   completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        // DNS work cannot block the main actor or the serial response/deadline queue.
        DispatchQueue.global(qos: .utility).async {
            let result: Result<Void, Error>
            do {
                guard let host = url.host else { throw JobDescriptionImportError.invalidURL }
                try Self.requirePublicAddresses(host)
                result = .success(())
            } catch { result = .failure(error) }
            self.queue.async { completion(result) }
        }
    }

    private static func requirePublicAddresses(_ host: String) throws {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if canImport(Darwin)
        hints.ai_socktype = SOCK_STREAM
        #else
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #endif
        var addresses: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &addresses) == 0, let first = addresses else {
            throw JobDescriptionImportError.networkUnavailable
        }
        defer { freeaddrinfo(first) }
        var current: UnsafeMutablePointer<addrinfo>? = first
        var found = false
        while let pointer = current {
            let info = pointer.pointee
            guard let address = info.ai_addr else { throw JobDescriptionImportError.unsafeURL }
            if info.ai_family == AF_INET {
                let ipv4 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee
                let raw = UInt32(bigEndian: ipv4.sin_addr.s_addr)
                let a = (raw >> 24) & 255
                let b = (raw >> 16) & 255
                let c = (raw >> 8) & 255
                let privateRange = a == 0 || a == 10 || a == 127 || a >= 224
                    || (a == 100 && (64...127).contains(b))
                    || (a == 169 && b == 254)
                    || (a == 172 && (16...31).contains(b))
                    || (a == 192 && b == 168)
                    || (a == 192 && b == 0 && (c == 0 || c == 2))
                    || (a == 198 && (b == 18 || b == 19))
                    || (a == 198 && b == 51 && c == 100)
                    || (a == 203 && b == 0 && c == 113)
                guard !privateRange else { throw JobDescriptionImportError.unsafeURL }
                found = true
            } else if info.ai_family == AF_INET6 {
                let ipv6 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in6.self).pointee
                let bytes = withUnsafeBytes(of: ipv6.sin6_addr) { Array($0) }
                let globalUnicast = bytes[0] & 0xe0 == 0x20
                let documentation = bytes[0...3].elementsEqual([0x20, 0x01, 0x0d, 0xb8])
                let transition = (bytes[0] == 0x20 && bytes[1] == 0x02)
                    || bytes[0...3].elementsEqual([0x20, 0x01, 0x00, 0x00])
                guard globalUnicast && !documentation && !transition else {
                    throw JobDescriptionImportError.unsafeURL
                }
                found = true
            } else { throw JobDescriptionImportError.unsafeURL }
            current = info.ai_next
        }
        guard found else { throw JobDescriptionImportError.networkUnavailable }
    }
}

