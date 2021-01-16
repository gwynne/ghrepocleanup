import Foundation

enum Github {
    struct User: Codable {
        let login: String
        let id: Int64
        let node_id: String
        let avatar_url: String
        let gravatar_id: String
        let url: String
        let html_url: String
        let followers_url: String
        let following_url: String
        let gists_url: String
        let starred_url: String
        let subscriptions_url: String
        let organizations_url: String
        let repos_url: String
        let events_url: String
        let received_events_url: String
        let type: String
        let site_admin: Bool
    }
    
    struct Team: Codable {
        let id: Int
        let node_id: String
        let url: String?
        let html_url: String?
        let members_url: String?
        let repositories_url: String?
        let name: String
        let slug: String
        let description: String?
        let privacy: String?
        let permission: String?
        let parent: String?
    }

    struct App: Codable {
        struct Permisssions: Codable {
            enum Permission: String, Hashable, Codable, CaseIterable {
                case read, write
            }
            let metadata, contents, issues, single_file: Permission
        }
        let id: Int
        let slug: String
        let node_id: String
        let owner: Github.User
        let name: String
        let description: String?
        let external_url: String?
        let html_url: String?
        let created_at: Date
        let updated_at: Date
        let permissions: Permisssions
        let events: [String]?
    }

    struct License: Codable {
        let key: String
        let name: String
        let spdx_id: String
        let url: String
        let node_id: String
    }
    
    struct Repository: Codable {
        enum Visibility: String, Codable {
            case `public`, `private`, `internal`
        }

        struct Permissions: Codable {
            let admin, push, pull: Bool
        }
        
        // basic
        let id: Int64
        let node_id: String
        let name: String
        let full_name: String
        let owner: User
        let organization: User?
        let description: String?
        
        // urls
        let homepage: String?
        let url: String
        let html_url, forks_url, keys_url, collaborators_url, teams_url, hooks_url, issue_events_url, events_url,
            assignees_url, branches_url, tags_url, blobs_url, git_tags_url, git_refs_url, trees_url, statuses_url,
            languages_url, stargazers_url, contributors_url, subscribers_url, subscription_url, commits_url,
            git_commits_url, comments_url, issue_comment_url, contents_url, compare_url, merges_url, archive_url,
            download_url, issues_url, pulls_url, milestones_url, notifications_url, labels_url, releases_url,
            deployments_url, git_url, ssh_url, clone_url, svn_url, mirror_url: String?
        
        // dates
        let created_at, updated_at, pushed_at: Date
        
        // counts
        let size: UInt64
        let stargazers_count: UInt64
        let watchers_count: UInt64
        let forks_count: UInt64
        let open_issues_count: UInt64
        let subscribers_count: UInt64?
        let network_count: UInt64?
        
        // settings
        let default_branch: String
        let language: String?
        let visibility: Visibility?
        
        // flags
        let `private`: Bool
        let fork: Bool
        let archived: Bool
        let disabled: Bool
        let is_template: Bool?
        let has_issues: Bool
        let has_projects: Bool
        let has_downloads: Bool
        let has_wiki: Bool
        let has_pages: Bool
        
        // misc
        let license: License?
        let permissions: Permissions
        let topics: [String]?
        let temp_clone_token: String?
        
        // merge settings
        let allow_merge_commit: Bool?
        let allow_rebase_merge: Bool?
        let allow_squash_merge: Bool?
        let delete_branch_on_merge: Bool?
    }

    struct GitUser: Codable {
        let date: Date
        let email: String
        let name: String
    }

    struct GitTree: Codable {
        let sha: String
        let url: String
        let html_url: String?
    }

    struct GitSignature: Codable {
        let payload: String?
        let reason: String
        let signature: String?
        let verified: Bool
    }

    struct Commit: Codable {
        struct CommitData: Codable {
            let author: GitUser
            let comment_count: UInt
            let committer: GitUser
            let message: String
            let tree: GitTree
            let url: String
            let verification: GitSignature?
        }
        let author: User
        let comments_url: String?
        let commit: CommitData
        let committer: User
        let html_url: String?
        let node_id: String
        let parents: [GitTree]?
        let sha: String
        let url: String
    }

    struct Branch: Codable {
        struct _Links: Codable {
            let html: String?
            let `self`: String?
        }

        let name: String
        let commit: Commit
        let protected: Bool?
        let protection: Protection?
        let protection_url: String?
        let _links: _Links?
    }

    enum Git {
        struct Object: Codable {
            let type: String
            let sha: String
            let url: String
        }
        
        struct Ref: Codable {
            let ref: String
            let node_id: String
            let url: String
            let object: Object
        }
    }

    struct Protection: Codable {
        struct StatusCheck: Codable {
            let url: String?
            let contexts: [String]?
            let contexts_url: String?
            let enforcement_level: String?
        }
        struct AdminEnforcement: Codable {
            let url: String?
            let enabled: Bool?
        }
        struct PullRequestReviewRequirements: Codable {
            struct DismissalRestrictions: Codable {
                let url, users_url, teams_url: String?
                let users: [Github.User]?
                let teams: [Github.Team]?
            }
            let url: String?
            let dismissal_restrictions: DismissalRestrictions?
            let dismiss_stale_reviews: Bool?
            let require_code_owner_reviews: Bool?
            let required_approving_review_count: UInt?
        }
        struct Restrictions: Codable {
            let url, users_url, teams_url, apps_url: String?
            let users: [Github.User]?
            let teams: [Github.Team]?
            let apps: [Github.App]?
        }
        struct EnableFlag: Codable { let enabled: Bool }
        let url: String?
        let enabled: Bool?
        let required_status_checks: StatusCheck?
        let enforce_admins: AdminEnforcement?
        let required_pull_request_reviews: PullRequestReviewRequirements?
        let restrictions: Restrictions?
        let required_linear_history: EnableFlag?
        let allow_force_pushes: EnableFlag?
        let allow_deletions: EnableFlag?
    }

    struct RepositoryUpdate: Codable {
        init(
            name: String? = nil,
            description: String? = nil,
            homepage: String? = nil,
            `private`: Bool? = nil,
            visibility: Github.Repository.Visibility? = nil,
            has_issues: Bool? = nil,
            has_projects: Bool? = nil,
            has_wiki: Bool? = nil,
            is_template: Bool? = nil,
            default_branch: String? = nil,
            allow_squash_merge: Bool? = nil,
            allow_merge_commit: Bool? = nil,
            allow_rebase_merge: Bool? = nil,
            delete_branch_on_merge: Bool? = nil,
            archived: Bool? = nil
        ) {
            self.name = name
            self.description = description
            self.homepage = homepage
            self.`private` = `private`
            self.visibility = visibility
            self.has_issues = has_issues
            self.has_projects = has_projects
            self.has_wiki = has_wiki
            self.is_template = is_template
            self.default_branch = default_branch
            self.allow_squash_merge = allow_squash_merge
            self.allow_merge_commit = allow_merge_commit
            self.allow_rebase_merge = allow_rebase_merge
            self.delete_branch_on_merge = delete_branch_on_merge
            self.archived = archived
        }
        
        let name: String?
        let description: String?
        let homepage: String?
        let `private`: Bool?
        let visibility: Github.Repository.Visibility?
        let has_issues: Bool?
        let has_projects: Bool?
        let has_wiki: Bool?
        let is_template: Bool?
        let default_branch: String?
        let allow_squash_merge: Bool?
        let allow_merge_commit: Bool?
        let allow_rebase_merge: Bool?
        let delete_branch_on_merge: Bool?
        let archived: Bool?
    }
    
    struct BranchProtectionUpdate: Codable {
        struct RequiredStatusChecks: Codable {
            let strict: Bool
            let contexts: [String]
        }
        struct RequiredPullRequestReviews: Codable {
            struct DismissalRestrictions: Codable {
                let users: [String]
                let teams: [String]
            }
            let dismissal_restrictions: DismissalRestrictions?
            let dismiss_stale_reviews: Bool
            let require_code_owner_reviews: Bool
            let required_approving_review_count: Int
        }
        struct Restrictions: Codable {
            let users: [String]
            let teams: [String]
            let apps: [String]?
        }
        let required_status_checks: RequiredStatusChecks?
        let enforce_admins: Bool?
        let required_pull_request_reviews: RequiredPullRequestReviews?
        let restrictions: Restrictions?
        let required_linear_history: Bool
        let allow_force_pushes: Bool
        let allow_deletions: Bool
    }
}
