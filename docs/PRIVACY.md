# Public repository privacy

Use generic companion labels and synthetic identities in source, tests and examples. Configure actual character identities only in the game's local SavedVariables. Keep private notes, account data, credentials and local installation details outside Git.

Installation examples use `<REPOSITORY_PATH>`, `<RETAIL_ADDONS_PATH>` and other explicit placeholders. Substitute actual paths locally; never commit those substitutions. Native game asset paths and project-relative file references are part of the addon implementation, not local installation configuration.

Use non-personal author metadata when publishing this repository. Review staged files and author/committer fields before pushing. Automated checks are a supplement to review and cannot identify every kind of personal information.

After a privacy history rewrite, existing collaborators should use a fresh clone rather than merge old history. Old clones, forks, cached commit views and pull-request references can retain removed content. A force push alone cannot guarantee erasure of those copies. Follow GitHub's [sensitive-data removal guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) for any eligible cached-view/server cleanup request. Avoid posting private details in public issues or commit messages.
