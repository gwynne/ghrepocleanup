# ghrepoclean

In its current form, this is a tool which iterates over all of the active repositories in a single GitHub organization and, where necessary, invokes GitHub's "rename branch" functionality to switch the default branch name from `master` to `main`. Private and archived repositories are ignored, as are any repository whose default branch is not `master`. Forks and pull requests are updated as per GitHub's guidelines for renaming the default branch; the rules are identical to performing the rename through the Web interface. Those rules, as they were presented by GitHub at the time of this writing, are as follows:

> Renaming this branch:
>
> Will update [N] pull requests targeting this branch across [N] repositories.
> Will update [N] branch protection rule that explicitly targets main.
> Will not update your members' local environments.
>
> Your members will have to manually update their local environments. We'll let > them know when they visit the repository, or you can share these commands:
>
> `git branch -m main <BRANCH>`
> `git fetch origin`
> `git branch -u origin/<BRANCH> <BRANCH>`
