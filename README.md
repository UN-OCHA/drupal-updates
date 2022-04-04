A lightly automated checklist to step through multiple drupal repos updating
core or contrib modules.

Inspired by [this blogpost.](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)

There's room for improvement - PRs welcome.

Assumptions:
* all the repositories are in the same parent directory
* names of repos to be updated are listed in `repolist.txt`, found in the same
directory as this script
* the repo has a `main` and a `develop` branch
* branch names are prefixed with a ticket number

If there's ongoing work in the `develop` branch that isn't ready to merge, it
will create a branch with the `feature/` prefix that can be merged direct to
`main`.

Caveats:
There are too many pauses for confirmation - as the script improves, they
should be removed.
