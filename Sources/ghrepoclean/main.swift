import ArgumentParser
//import ConsoleKit
import NetworkClient
import Foundation
import AsyncHTTPClient
import NIOHTTP1
import NIO
import NIOTransportServices
import AsyncKit
import Logging

extension EventLoopFuture {
    public func whenComplete(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        self.whenComplete { result in
            switch result {
                case .success(let value): return success(value)
                case .failure(let error): return failure(error)
            }
        }
    }
    
    public func annotate(_ callback: @escaping (Value) -> Void) -> EventLoopFuture<Value> {
        return self.map {
            callback($0)
            return $0
        }
    }
}

public struct EventLoopNetworkClient {
    public let eventLoop: EventLoop
    public let client: NetworkClient
    
    public init(with client: NetworkClient, on eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.client = client
    }
    
    public func load<Request: NetworkRequest>(_ req: Request) -> EventLoopFuture<Request.ResponseDataType> {
        return self.client.load(req, hoppingTo: self.eventLoop)
    }
}

extension NetworkClient {
    public func load<Request: NetworkRequest>(_ req: Request, hoppingTo eventLoop: EventLoop) -> EventLoopFuture<Request.ResponseDataType> {
        let promise = eventLoop.makePromise(of: Request.ResponseDataType.self)
        
        self.load(req, completion: promise.completeWith(_:))
        return promise.futureResult
    }
}

extension EventLoopNetworkClient {
    func GHListOrgRepositories(
        name: String,
        type: GithubAPI.ListOrgRepositories.RepoType? = nil,
        sortBy: GithubAPI.ListOrgRepositories.Sort? = nil, sortAscending: Bool? = nil,
        resultsPerPage: Int? = nil, page: Int? = nil
    ) -> EventLoopFuture<GithubAPI.ListOrgRepositories.ResponseDataType> {
        return self.load(
            GithubAPI.ListOrgRepositories(name: name, type: type, sortBy: sortBy, sortAscending: sortAscending, resultsPerPage: resultsPerPage, page: page)
        )
    }
    
    func GHUpdateRepository(
        _ repo: Github.Repository, to settings: Github.RepositoryUpdate
    ) -> EventLoopFuture<GithubAPI.UpdateRepository.ResponseDataType> {
        return self.load(GithubAPI.UpdateRepository(owner: repo.owner.login, repo: repo.name, update: settings))
    }
    
    func GHGetRef(branch: String, from repo: Github.Repository) -> EventLoopFuture<GithubAPI.GetRef.ResponseDataType> {
        return self.load(GithubAPI.GetRef.branch(branch, from: repo))
    }
    func GHGetRef(tag: String, from repo: Github.Repository) -> EventLoopFuture<GithubAPI.GetRef.ResponseDataType> {
        return self.load(GithubAPI.GetRef.tag(tag, from: repo))
    }
    
    func GHCreateRef(branch: String, at sha: String, in repo: Github.Repository) -> EventLoopFuture<GithubAPI.CreateRef.ResponseDataType> {
        return self.load(GithubAPI.CreateRef.branch(branch, at: sha, in: repo))
    }
    func GHCreateRef(tag: String, at sha: String, in repo: Github.Repository) -> EventLoopFuture<GithubAPI.CreateRef.ResponseDataType> {
        return self.load(GithubAPI.CreateRef.tag(tag, at: sha, in: repo))
    }
    
    func GHGetBranchProtection(
        _ branch: String, in repo: Github.Repository
    ) -> EventLoopFuture<GithubAPI.GetBranchProtection.ResponseDataType> {
        return self.load(GithubAPI.GetBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch))
    }
    
    func GHUpdateBranchProtection(
        _ branch: String, in repo: Github.Repository, to protection: Github.BranchProtectionUpdate
    ) -> EventLoopFuture<GithubAPI.UpdateBranchProtection.ResponseDataType> {
        return self.load(GithubAPI.UpdateBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch, update: protection))
    }
    
    func GHDeleteBranchProtection(
        _ branch: String, in repo: Github.Repository
    ) -> EventLoopFuture<GithubAPI.DeleteBranchProtection.ResponseDataType> {
        return self.load(GithubAPI.DeleteBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch))
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) { self.init(string: argument) }
}

@main
struct CleanCommand: ParsableCommand {

    @Option(name: .shortAndLong)
    var username: String
    
    @Option(name: .shortAndLong)
    var password: String
    
    @Option(name: .long)
    var endpoint: URL = URL(string: "https://api.github.com")!
    
    @Argument
    var org: String = "vapor"
    
    init() {}
    
    private func makeELG() -> EventLoopGroup {
        let elg: EventLoopGroup
        
        #if canImport(Network)
            if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
                elg = NIOTSEventLoopGroup()
            } else {
                elg = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            }
        #else
            elg = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
        
        return elg
    }
    
    private func process(repo: Github.Repository, with client: EventLoopNetworkClient, logger: Logger) -> EventLoopFuture<Void> {
        return client.eventLoop.flatSubmit { () -> EventLoopFuture<Github.Git.Ref> in
            logger.info("Getting 'master' ref")
            
            return client.GHGetRef(branch: "master", from: repo)
        }
        .flatMap { ref -> EventLoopFuture<Github.Git.Ref> in
            logger.trace("Master ref: \(ref)")
            logger.notice("Creating 'main' ref at original 'master' SHA \(ref.object.sha)")

            return client.GHCreateRef(branch: "main", at: ref.object.sha, in: repo)
        }
        .flatMap { _ -> EventLoopFuture<Github.Protection> in
            logger.info("Getting branch protection for 'master'")

            return client.GHGetBranchProtection("master", in: repo)
        }
        .flatMap { prot -> EventLoopFuture<Void> in
            logger.trace("Master branch protection: \(prot)")
            logger.notice("Applying branch protections to new 'main' branch")

            return client.GHUpdateBranchProtection("main", in: repo, to: .init(
                required_status_checks: .init(
                    strict: true,
                    contexts: prot.required_status_checks?.contexts ?? []
                ),
                enforce_admins: false,
                required_pull_request_reviews: .init(
                    dismissal_restrictions: .init(
                        users: prot.required_pull_request_reviews?.dismissal_restrictions?.users?.map { $0.login } ?? [],
                        teams: prot.required_pull_request_reviews?.dismissal_restrictions?.teams?.map { $0.name } ?? []
                    ),
                    dismiss_stale_reviews: false,
                    require_code_owner_reviews: false,
                    required_approving_review_count: 1
                ),
                restrictions: nil,
                required_linear_history: false,
                allow_force_pushes: false,
                allow_deletions: false
            ))
        }
        .flatMap { _ -> EventLoopFuture<Void> in
            logger.notice("Resetting 'master' branch protections and locking it")

            return client.GHUpdateBranchProtection("master", in: repo, to: .init(
                required_status_checks: nil,
                enforce_admins: true,
                required_pull_request_reviews: nil,
                restrictions: .init(users: [], teams: [], apps: []),
                required_linear_history: false,
                allow_force_pushes: false,
                allow_deletions: false
            ))
        }
        .flatMap { _ -> EventLoopFuture<Github.Repository> in
            logger.notice("Updating default branch to 'main' and normalizing settings")

            return client.GHUpdateRepository(repo, to: .init(
                default_branch: "main",
                allow_squash_merge: true,
                allow_merge_commit: false,
                allow_rebase_merge: false,
                delete_branch_on_merge: true
            ))
        }
        .transform(to: ())
    }
    
    private func perform(with client: EventLoopNetworkClient, logger: Logger) -> EventLoopFuture<Void> {
        return client.eventLoop.flatSubmit { () -> EventLoopFuture<[Github.Repository]> in
            logger.notice("Listing repos owned by '\(self.org)'")

            return client.GHListOrgRepositories(name: self.org, type: .public, resultsPerPage: 100)
        }
        .map { repos -> [Github.Repository] in
            let activeRepos = repos.filter { !$0.archived && !$0.private && !$0.fork && !$0.disabled }
            let legacyBranchNameRepos = activeRepos.filter { $0.default_branch == "master" }
            
            logger.info("Listed \(repos.count) repositories.")
            logger.trace("All repositories:\n\t\(repos.map { $0.name }.joined(separator: "\n\t"))")
            
            logger.info("\(activeRepos.count) repositories are active (public, not archived, not a fork, and not disabled).")
            logger.trace("All active repositories:\n\t\(activeRepos.map { $0.name }.joined(separator: "\n\t"))")
            
            logger.info("There are \(legacyBranchNameRepos.count) active repositories whose default branch is 'master':")
            logger.info("\t\(legacyBranchNameRepos.map { $0.name }.joined(separator: "\n\t"))")
            
            return legacyBranchNameRepos
        }
        .sequencedFlatMapEach { repo -> EventLoopFuture<Void> in
            logger.notice("Working on repo '\(repo.full_name)'")
            
            var newLogger = logger
            newLogger[metadataKey: "repo"] = "\(repo.full_name)"
            return self.process(repo: repo, with: client, logger: newLogger)
        }
    }
    
    mutating func run() throws {
        LoggingSystem.bootstrap { StreamLogHandler.standardOutput(label: $0) }
        
        var logger = Logger(label: "run")
        logger.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap { Logger.Level(rawValue: $0) } ?? .info
        
        let elg = self.makeELG()
        
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(elg), configuration: .init(
            certificateVerification: .fullVerification,
            redirectConfiguration: .disallow,
            decompression: HTTPClient.Decompression.enabled(limit: .none)
        ))
        let authorizationProvider = AuthorizationProvider(
            base: httpClient,
            initialAuthorization: .basic(username: self.username, password: self.password),
            newCredentialsCallback: nil
        )
        let transport = AddHeaders(base: authorizationProvider, headers: [
            "Accept": "application/vnd.github.v3+json"
        ])
        let client = NetworkClient(baseURL: self.endpoint, transport: transport, logger: logger)
        
        defer {
            try! httpClient.syncShutdown()
            try! elg.syncShutdownGracefully()
        }
        
        try self.perform(with: EventLoopNetworkClient(with: client, on: elg.next()), logger: logger)
            .flatMapErrorThrowing { error in
                if case .api(let status, let body) = error as? APIError {
                    logger.error("HTTP error: \(status.localizedDescription)")
                    if !body.isEmpty {
                        logger.error("Server response:")
                        logger.error("\n\(String(decoding: body, as: UTF8.self))")
                    }
                }
                throw error
            }
            .wait()
        
        logger.notice("Done.")
    }
}
