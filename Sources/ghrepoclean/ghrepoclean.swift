import ArgumentParser
import ConsoleKit
import NetworkClient
import Foundation
import AsyncHTTPClient
import NIOHTTP1
import NIO
import NIOTransportServices
import AsyncKit
import Logging
import Dispatch

extension Logger {
    public func withAdditionalPersistentMetadata(_ metadata: Metadata) -> Logger {
        var copy = self
        
        metadata.forEach { copy[metadataKey: $0] = $1 }
        return copy
    }
}

extension NetworkClient {
   public func load<Request: NetworkRequest>(_ req: Request) async throws -> Request.ResponseDataType {
        return try await withCheckedThrowingContinuation { continuation in
            self.load(req) { switch $0 {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
            } }
        }
    }
}

extension NetworkClient {
    func GHListOrgRepositories(
        name: String,
        type: GithubAPI.ListOrgRepositories.RepoType? = nil,
        sortBy: GithubAPI.ListOrgRepositories.Sort? = nil, sortAscending: Bool? = nil,
        resultsPerPage: Int? = nil, page: Int? = nil
    ) async throws -> GithubAPI.ListOrgRepositories.ResponseDataType {
        try await self.load(
            GithubAPI.ListOrgRepositories(name: name, type: type, sortBy: sortBy, sortAscending: sortAscending, resultsPerPage: resultsPerPage, page: page)
        )
    }
    
    func GHUpdateRepository(_ repo: Github.Repository, to settings: Github.RepositoryUpdate) async throws -> GithubAPI.UpdateRepository.ResponseDataType {
        try await self.load(GithubAPI.UpdateRepository(owner: repo.owner.login, repo: repo.name, update: settings))
    }
    
    func GHGetRef(branch: String, from repo: Github.Repository) async throws -> GithubAPI.GetRef.ResponseDataType {
        try await self.load(GithubAPI.GetRef.branch(branch, from: repo))
    }
    func GHGetRef(tag: String, from repo: Github.Repository) async throws -> GithubAPI.GetRef.ResponseDataType {
        try await self.load(GithubAPI.GetRef.tag(tag, from: repo))
    }
    
    func GHCreateRef(branch: String, at sha: String, in repo: Github.Repository) async throws -> GithubAPI.CreateRef.ResponseDataType {
        try await self.load(GithubAPI.CreateRef.branch(branch, at: sha, in: repo))
    }
    func GHCreateRef(tag: String, at sha: String, in repo: Github.Repository) async throws -> GithubAPI.CreateRef.ResponseDataType {
        try await self.load(GithubAPI.CreateRef.tag(tag, at: sha, in: repo))
    }
    
    func GHGetBranch(_ branch: String, in repo: Github.Repository) async throws -> GithubAPI.GetBranch.ResponseDataType {
        try await self.load(GithubAPI.GetBranch(owner: repo.owner.login, repo: repo.name, branch: branch))
    }
    
    func GHGetBranchProtection(_ branch: Github.Branch, in repo: Github.Repository) async throws -> GithubAPI.GetBranchProtection.ResponseDataType {
        try await self.load(GithubAPI.GetBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch.name))
    }
    
    func GHUpdateBranchProtection(
        _ branch: Github.Branch, in repo: Github.Repository, to protection: Github.BranchProtectionUpdate
    ) async throws -> GithubAPI.UpdateBranchProtection.ResponseDataType {
        try await self.load(GithubAPI.UpdateBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch.name, update: protection))
    }
    
    func GHDeleteBranchProtection(_ branch: Github.Branch, in repo: Github.Repository) async throws -> GithubAPI.DeleteBranchProtection.ResponseDataType {
        try await self.load(GithubAPI.DeleteBranchProtection(owner: repo.owner.login, repo: repo.name, branch: branch.name))
    }
    
    func GHRenameBranch(_ branch: String, in repo: Github.Repository, to newName: String) async throws -> GithubAPI.RenameBranch.ResponseDataType {
        try await self.load(GithubAPI.RenameBranch(owner: repo.owner.login, repo: repo.name, branch: branch, new_name: newName))
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) { self.init(string: argument) }
}

@main
struct Entry {
    public static func main() {
        do {
            var command = try CleanCommand.parseAsRoot(nil)
            if var aCommand = command as? CleanCommand {
                try aCommand.run()
            } else {
                try command.run()
            }
        } catch {
            CleanCommand.exit(withError: error)
        }
    }
}

struct CleanCommand: ParsableCommand {

    @ArgumentParser.Option(name: .shortAndLong)
    var username: String
    
    @ArgumentParser.Option(name: .shortAndLong)
    var password: String
    
    @ArgumentParser.Option(name: .long)
    var endpoint: URL = URL(string: "https://api.github.com")!
    
    @ArgumentParser.Argument
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
    
    private static func safelyRenameBranch(in repo: Github.Repository, from branch: String, to newName: String, client: NetworkClient, logger: Logger) async throws -> Github.Branch {
        do {
            logger.notice("Renaming branch '\(branch)' to '\(newName)'")
            return try await client.GHRenameBranch(branch, in: repo, to: newName)
        } catch APIError.api(let status, _) where status == .notFound {
            logger.notice("No such branch '\(branch)', checking if new name '\(newName)' already exists")
            return try await client.GHGetBranch(newName, in: repo)
        }
    }
    
    private static func process(repo: Github.Repository, with client: NetworkClient, logger: Logger) async throws {
        let mainBranch = try await self.safelyRenameBranch(in: repo, from: "master", to: "main", client: client, logger: logger)
        
        return ()
        
//        logger.info("Getting branch protection for 'main'")
//        let mainProt = try await client.GHGetBranchProtection(mainBranch, in: repo)
//
//        logger.debug("Main branch protection: \(mainProt)")
//
//        logger.notice("Normalizing branch protections on 'main' branch")
//        try await client.GHUpdateBranchProtection(mainBranch, in: repo, to: .init(
//            required_status_checks: .init(
//                strict: true,
//                contexts: mainProt.required_status_checks?.contexts ?? []
//            ),
//            enforce_admins: false,
//            required_pull_request_reviews: .init(
//                dismissal_restrictions: .init(
//                    users: mainProt.required_pull_request_reviews?.dismissal_restrictions?.users?.map { $0.login } ?? [],
//                    teams: mainProt.required_pull_request_reviews?.dismissal_restrictions?.teams?.map { $0.name } ?? []
//                ),
//                dismiss_stale_reviews: false,
//                require_code_owner_reviews: false,
//                required_approving_review_count: 1
//            ),
//            restrictions: .init(users: [], teams: [], apps: nil),
//            required_linear_history: false,
//            allow_force_pushes: false,
//            allow_deletions: false
//        ))
//
//        logger.notice("Normalizing repo settings")
//        _ = try await client.GHUpdateRepository(repo, to: .init(
//            allow_squash_merge: true,
//            allow_merge_commit: false,
//            allow_rebase_merge: false,
//            delete_branch_on_merge: true
//        ))
    }
    
    private static func perform(org: String, with client: NetworkClient, logger: Logger) async throws {
        logger.notice("Listing repos owned by '\(org)'")
        let repos = try await client.GHListOrgRepositories(name: org, type: .public, resultsPerPage: 100)
        let activeRepos = repos.filter { !$0.archived && !$0.private && !$0.fork && !$0.disabled }
            
        logger.info("Listed \(repos.count) repositories.")
        logger.debug("All repositories:\n\t\(repos.map { $0.name }.joined(separator: "\n\t"))")
        
        logger.info("\(activeRepos.count) repositories are active (public, not archived, not a fork, and not disabled).")
        logger.debug("All active repositories:\n\t\(activeRepos.map { $0.name }.joined(separator: "\n\t"))")
        
        for repo in activeRepos {
            logger.notice("Starting work on repo '\(repo.full_name)'")
            try await self.process(repo: repo, with: client, logger: logger.withAdditionalPersistentMetadata([
                "repo": "\(repo.full_name)"
            ]))
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
        
        let org = self.org
        
        do {
            try runAsyncAndBlockThrowing { try await Self.perform(org: org, with: client, logger: logger) }
        } catch APIError.api(let status, let body) {
            logger.error("HTTP error: \(status.localizedDescription)")
            if !body.isEmpty {
                logger.error("Server response:")
                logger.error("\n\(String(decoding: body, as: UTF8.self))")
            }
            throw APIError.api(status: status, body: body)
        }
        logger.notice("Done.")
    }
}

public func runAsyncAndBlockThrowing<R>(_ asyncFun: @escaping () async throws -> R) throws -> R {
    var result: Result<R, Error>? = nil

    runAsyncAndBlock {
        do {
            result = .success(try await asyncFun())
        } catch {
            result = .failure(error)
        }
    }
    return try result!.get()
}
