# Terraform Docs with Required Status Example

## Problem

`terraform-docs` is a free open-source utility to generate documentation from Terraform modules in various output formats. It can be ran in multiple ways, including within a GitHub Actions pipeline. When `terraform-docs` runs, it commits the output back into the repository. It utilizes the existing pipeline's authentication, which is usually the built-in `GITHUB_TOKEN`.

<details>

<summary>Basic Workflow Example With Issue</summary>

```yaml
   name: on pull request

on: [pull_request]

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  plan:
    runs-on: ubuntu-latest
    name: run terraform plan
    env:
      GITHUB_TOKEN: ${{ github.token }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: terraform plan
        uses: dflook/terraform-plan@a8d7e66e63aff79825a46e3374c4fd66ff9ce543
        id: terraform-plan
        with:
          path: .
          var_file: |
            test/tfvars/ci.auto.tfvars

  docs:
    needs: plan
    runs-on: ubuntu-latest
    name: create readme
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.pull_request.head.ref }}

      - name: "terraform docs creation"
        id: "terraform-docs"
        uses: terraform-docs/gh-actions@cfde42f79b15256c71f4b79ae1d6acea0f689952
        with:
          working-dir: .
          config-file: ./test/terraform-docs/.terraform-docs.yml
          output-file: terraform-docs.md
          output-method: replace
          git-push: "true"
        continue-on-error: false
```

</details>

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

### Repo Configuration [^3]

- Go to the repo where `terraform-docs` will be used
- Create 2 secrets:
  - `APP_ID` - This will be the App ID as noted above
  - `APP_SECRET` - This will be the entire PEM file that was downloaded upon creating a private key including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`

### Workflow Updates - Basic

Within the PR Workflow, a few modifications are needed. For the full example, see [.github/workflows/on-pull-request.yml](.github/workflows/on-pull-request.yml).

- Add the following block of code as the very first step within the job `docs`

  ```yml
  - name: Generate token
    id: generate_token
    uses: tibdex/github-app-token@b62528385c34dbc9f38e5f4225ac829252d1ea92
    with:
      app_id: ${{ secrets.APP_ID }}
      private_key: ${{ secrets.APP_SECRET }}
  ```

- Within the next step `actions/checkout@v3`, include the additional parameter `token: ${{ steps.generate_token.outputs.token }}`
  ```yml
  - uses: actions/checkout@v3
    with:
      ref: ${{ github.event.pull_request.head.ref }}
      token: ${{ steps.generate_token.outputs.token }}
  ```

With these 2 additions, the next time `terraform-docs` makes a commit, it will come from the new GitHub App. This will trigger the workflows to restart and evaluate the new commit and maintain the status checks for the PR.

#### Potential Unwanted Behavior

# Sources:

[^1]: https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token
[^2]: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app
[^3]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions#example-workflow-authenticating-with-a-github-app
