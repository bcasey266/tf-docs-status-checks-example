# Terraform Docs with Required Status Example

## Problem

`terraform-docs` is a free open-source utility to generate documentation from Terraform modules in various output formats. It can be ran in multiple ways, including within a GitHub Actions pipeline. When `terraform-docs` runs, it commits the output back into the repository. It utilizes the existing pipeline's authentication, which is usually the built-in `GITHUB_TOKEN`.

This functionality works well unless the user wants to see a Pull Request's status checks. If those same status checks are required, this functionality fully breaks it.

This problem is due to the combination of factors:

1. The Status Checks are started from the initial commit into the Pull Request
2. `terraform-docs` performs an additional commit to update it's output file
3. The `GITHUB_TOKEN` is not able to trigger additional workflows [^1]. This is the token that `terraform-docs` is likely using which prevents the status checks from reoccurring and invalidating the checks that just ran.

&nbsp;

| Broken Example                                          | Working Example                                          |
| ------------------------------------------------------- | -------------------------------------------------------- |
| ![Broken Example](./resources/images/BrokenExample.png) | ![Broken Example](./resources/images/WorkingExample.png) |

&nbsp;

## Solution

### High Level

The overall solution to this problem is to use a different token then `GITHUB_TOKEN`. However, utilizing Personal Access Tokens (PAT) is not a secure method and should be avoided when possible. Instead, a GitHub App should be created and utilized.

### Creating a GitHub App [^2]

- In the upper-right corner of any page on GitHub, click your profile photo.
- Navigate to your account settings.
  - For a GitHub App owned by a personal account, click Settings.
  - For a GitHub App owned by an organization:
    - Click Your organizations.
    - To the right of the organization, click Settings.
- In the left sidebar, click Developer settings.
- In the left sidebar, click GitHub Apps.
- Click New GitHub App.
- Under "GitHub App name", enter a name for your app. The name must be unique across GitHub. You cannot use same name as an existing GitHub account, unless it is your own user or organization name.
- Under "Homepage URL", type URL of the organization or user that owns the app.
- Under the "Webhook" section, uncheck "Active"
- Under Permissions, Provide "Read & Write" to `Contents` under `Repository Permissions`
- Click `Create GitHub App`
- Note the `App ID`
- Scroll down and select the button `Generate a private key`
- On the left bar, select `Install App` > `Install`
- Provide Access to either all Repositories or specify a subset

# Sources:

[^1]: https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token
[^2]: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app
[^3]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions#example-workflow-authenticating-with-a-github-app
