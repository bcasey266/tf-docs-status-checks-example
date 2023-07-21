# Terraform Docs with Required Status Example

## Problem

`terraform-docs` is a free open-source utility to generate documentation from Terraform modules in various output formats. It can be ran in multiple ways, including within a GitHub Actions pipeline. When `terraform-docs` runs, it commits the output back into the repository. It utilizes the existing pipeline's authentication, which is usually the built-in `GITHUB_TOKEN`.

This functionality works well unless the user wants to see a Pull Request's status checks. If those same status checks are required, this functionality fully breaks it.

This problem is due to the combination of factors:

1. The Status Checks are started from the initial commit into the Pull Request
2. `terraform-docs` performs an additional commit to update it's output file
3. The `GITHUB_TOKEN` is not able to trigger additional workflows [^1]. This is the token that `terraform-docs` is likely using which prevents the status checks from reoccurring and invalidating the checks that just ran.

| Broken Example                                          | Working Example                                          |
| ------------------------------------------------------- | -------------------------------------------------------- |
| ![Broken Example](./resources/images/BrokenExample.png) | ![Broken Example](./resources/images/WorkingExample.png) |

[^1]: https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token
