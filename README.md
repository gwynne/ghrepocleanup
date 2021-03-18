# ghrepoclean

In its current form, this is a tool which iterates over all of the active repositories in a single GitHub organization and, where necessary, invokes GitHub's "rename branch" functionality to switch the default branch name from `master` to `main`. [See below for detailed information](#some-details) on the tool's operation at runtime.

This version of the implementation (as of March 2021) makes heavy use of the new experimental concurrency support in Swift 5.4. A few informative references:

* [SE-0296 Async/await]( https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
* [SE-0294 Declaring executable targets in Package Manifests](https://github.com/apple/swift-evolution/blob/main/proposals/0294-package-executable-targets.md)
* [SE-0300 Continuations for interfacing async tasks with synchronous code](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
* [SE-0304 Structured concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)

# Successful Use By Vapor

This tool, as it existed at commit [9c27894a4afe5b7d29931c525189086698b45f09](https://github.com/gwynne/ghrepocleanup/commit/9c27894a4afe5b7d29931c525189086698b45f09), was invoked for the [Vapor GitHub organization](https://github.com/vapor/) on March 11, 2021; it processed 63 repositories, correctly bypassed those whose default branch was already correctly named, and successfully renamed every remaining repository's default branch with zero errors. The code was built and run using the 2021-02-26 Swift trunk development snapshot toolchain (several later versions having had showstopping issues with the actively evolving concurrency implementation) in Xcode 12.5 beta 3. It took approximately 6 minutes to build and run from start to finish from a fully cleaned state, of which the build step (as expected) took by far the majority.

## GitHub API interface

The interface to GitHub uses the traditional [REST API](https://docs.github.com/en/rest). All of the common model types accepted by and/or returned by the various APIs used by this code have been built out manually as `Codable` types with `NetworkRequest` conformances (see the dependencies section below). These models, along with a set of namespaced utility methods for invoking the APIs (those which have been coded thus far, at least), are set out in separate source files in what is intended to be modular fashion, with the intent of either extending them further, or possibly switching to making use of the [OpenAPI description](https://github.com/github/rest-api-description) for automated coverage.

## Dependency Notes and Praise

The code invokes GitHub's API through [AsyncHTTPClient](https://github.com/swift-server/async-http-client), as encapsulated by [Thomas Krajacic](https://github.com/tkrajacic)'s excellent [NetworkClient](https://github.com/stairtree/NetworkClient) package (the latter of which is a work in progress but well worth keeping an eye on!).

[ArgumentParser](https://github.com/apple/swift-argument-parser) and [Logging](https://github.com/apple/swift-log) also make appearances, and the code also borrows a few utilities from Vapor's [AsyncKit](https://github.com/vapor/async-kit).

_Note: While Vapor's [ConsoleKit](https://github.com/vapor/console-kit) is listed as a dependency in `Package.swift`, at the time of this writing, it is not actually used by this code. That may or may not change later._

## Some details

Private and archived repositories are ignored, as are any repository whose default branch is not `master`. Forks and pull requests are updated as per GitHub's guidelines for renaming the default branch; the rules are identical to performing the rename through the Web interface. Those rules, as they were presented by GitHub at the time of this writing, are as follows:

> **Renaming this branch:**
>
> Will update [N] pull requests targeting this branch across [N] repositories.
> Will update [N] branch protection rule that explicitly targets main.
> Will not update your members' local environments.
>
> Your members will have to manually update their local environments. We'll let
> them know when they visit the repository, or you can share these commands:
>
> `git branch -m main <BRANCH>`<br>
> `git fetch origin`<br>
> `git branch -u origin/<BRANCH> <BRANCH>`<br>
