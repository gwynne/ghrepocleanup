import Foundation
import NetworkClient
import NIOHTTP1

protocol GithubAPIRequest: NetworkRequest where ResponseDataType: Codable {}

extension GithubAPIRequest {
    func parseResponse(_ data: Data) throws -> ResponseDataType {
        return try GithubAPI.jsonDecoder.decode(data: data)
    }
}

enum GithubAPI {
    static var jsonEncoder: JSONEncoder = .init(dateEncodingStrategy: .iso8601)
    static var jsonDecoder: JSONDecoder = .init(dateDecodingStrategy: .iso8601)
    
    enum RefType: String, Hashable, CaseIterable {
        case branch = "heads", tag = "tags", pull = "pull"
    }
    
    struct ListOrgRepositories: GithubAPIRequest {
        enum RepoType: String, Codable, CaseIterable {
            case all, `public`, `private`, forks, sources, member, `internal`
        }
        enum Sort: String, Codable, CaseIterable {
            case created, updated, pushed, full_name
        }
        
        typealias ResponseDataType = [Github.Repository]

        let name: String
        let type: RepoType?
        let sortBy: Sort?
        let sortAscending: Bool?
        let resultsPerPage: Int?
        let page: Int?
        
        init(name: String, type: RepoType? = nil, sortBy: Sort? = nil, sortAscending: Bool? = nil, resultsPerPage: Int? = nil, page: Int? = nil) {
            self.name = name
            self.type = type
            self.sortBy = sortBy
            self.sortAscending = sortAscending
            self.resultsPerPage = resultsPerPage
            self.page = page
        }
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            .init(url: baseURL.traversing("orgs", self.name, for: "repos").withQuery(items:
                .init(name: "type", requiredValue: self.type?.rawValue),
                .init(name: "sort", requiredValue: self.sortBy?.rawValue),
                .init(name: "direction", requiredValue: self.sortAscending.map { $0 ? "asc" : "desc" }),
                .init(name: "per_page", requiredValue: self.resultsPerPage),
                .init(name: "page", requiredValue: self.page)
            )!)
        }
    }
    
    struct UpdateRepository: GithubAPIRequest {
        typealias ResponseDataType = Github.Repository
        
        let owner: String
        let repo: String
        let update: Github.RepositoryUpdate
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            var request = URLRequest(url: baseURL.traversing("repos", self.owner, self.repo), method: HTTPMethod.PATCH.rawValue)
            request.httpBody = try GithubAPI.jsonEncoder.encode(self.update)
            return request
        }
    }
    
    struct GetBranch: GithubAPIRequest {
        typealias ResponseDataType = Github.Branch
        
        let owner: String
        let repo: String
        let branch: String
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            .init(url: baseURL.traversing("repos", self.owner, self.repo, "branches", for: self.branch))
        }
    }
    
    struct GetBranchProtection: GithubAPIRequest {
        typealias ResponseDataType = Github.Protection
        
        let owner: String
        let repo: String
        let branch: String
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            .init(url: baseURL.traversing("repos", self.owner, self.repo, "branches", self.branch, for: "protection"))
        }
    }
    
    struct UpdateBranchProtection: NetworkRequest {
        typealias ResponseDataType = Void
        
        let owner: String
        let repo: String
        let branch: String
        let update: Github.BranchProtectionUpdate
                
        func makeRequest(baseURL: URL) throws -> URLRequest {
            var request = URLRequest(url: baseURL.traversing("repos", self.owner, self.repo, "branches", self.branch, for: "protection"), method: HTTPMethod.PUT.rawValue)
            request.httpBody = try GithubAPI.jsonEncoder.encode(self.update)
            request.setValue("application/vnd.github.luke-cage-preview+json", forHTTPHeaderField: "accept")
            return request
        }
        
        func parseResponse(_ data: Data) throws -> Void {}
    }
    
    struct DeleteBranchProtection: NetworkRequest {
        typealias ResponseDataType = Void
        
        let owner: String
        let repo: String
        let branch: String

        func makeRequest(baseURL: URL) throws -> URLRequest {
            .init(url: baseURL.traversing("repos", self.owner, self.repo, "branches", self.branch, for: "protection"), method: HTTPMethod.DELETE.rawValue)
        }
        
        func parseResponse(_ data: Data) throws -> Void {}
    }
    
    struct RenameBranch: GithubAPIRequest {
        typealias ResponseDataType = Github.Branch
        
        let owner: String
        let repo: String
        let branch: String
        let new_name: String
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            var request = URLRequest(url: baseURL.traversing("repos", self.owner, self.repo, "branches", self.branch, for: "rename"), method: HTTPMethod.POST.rawValue)
            request.httpBody = try GithubAPI.jsonEncoder.encode(["new_name": self.new_name])
            return request
        }
    }
    
    struct GetRef: GithubAPIRequest {
        typealias ResponseDataType = Github.Git.Ref

        let owner: String
        let repo: String
        let type: RefType
        let name: String
        
        static func branch(_ branch: String, from repo: Github.Repository) -> Self { .init(owner: repo.owner.login, repo: repo.name, type: .branch, name: branch) }
        static func tag(_ tag: String, from repo: Github.Repository) -> Self { .init(owner: repo.owner.login, repo: repo.name, type: .tag, name: tag) }
        
        func makeRequest(baseURL: URL) throws -> URLRequest {
            .init(url: baseURL.traversing("repos", self.owner, self.repo, "git", "ref", self.type.rawValue, for: self.name))
        }
    }
    
    struct CreateRef: GithubAPIRequest {
        typealias ResponseDataType = Github.Git.Ref

        let owner: String
        let repo: String
        let type: RefType
        let name: String
        let sha: String
        
        static func branch(_ branch: String, at sha: String, in repo: Github.Repository) -> Self {
            .init(owner: repo.owner.login, repo: repo.name, type: .branch, name: branch, sha: sha)
        }
        
        static func tag(_ tag: String, at sha: String, in repo: Github.Repository) -> Self {
            .init(owner: repo.owner.login, repo: repo.name, type: .tag, name: tag, sha: sha)
        }

        func makeRequest(baseURL: URL) throws -> URLRequest {
            var request = URLRequest(url: baseURL.traversing("repos", self.owner, self.repo, "git", for: "refs"))
            request.httpMethod = HTTPMethod.POST.rawValue
            request.httpBody = try GithubAPI.jsonEncoder.encode(["ref": "refs/\(self.type.rawValue)/\(self.name)", "sha": self.sha])
            return request
        }
    }
}

