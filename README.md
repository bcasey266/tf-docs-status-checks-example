# Terraform Docs with Required Status Example

## Problem

**terraform-docs**[^1] is a powerful open-source utility that can help you keep your Terraform modules well-documented by automatically generating documentation. The two most popular ways to run **terraform-docs** is locally from a command line or from within a CI/CD pipeline like **GitHub Actions**. When **terraform-docs** runs within a **GitHub Actions** pipeline, it commits the output back into the repository. **terraform-docs** does not have a built-in authentication method, so it utilizes the existing pipeline's authentication, which is usually the native `GITHUB_TOKEN`.

This functionality works well unless the workflow runs during a _Pull Request_ with other workflows. Each job within a workflow shows up in the _Pull Request_ as a _Status Check_. **terraform-docs** causes the _Status Checks_ from showing up after **terraform-docs** makes it's commit into the repository. This causes an inconvenience if the _Status Checks_ are optional, but if those _Status Checks_ are required, this behavior becomes incompatible.

The problem is due to a combination of factors:

1. The _Status Checks_ are started from the initial commit into the _Pull Request_
2. **terraform-docs** performs an additional commit to update it's output/documentation file
3. The `GITHUB_TOKEN` is not able to trigger additional workflows[^2]. This is the token that **terraform-docs** is likely using which prevents the status checks from reoccurring and invalidating the checks that just ran.

&nbsp;

<details>

<summary>Workflow Example With Problem</summary>

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

&nbsp;

| Broken Example                                          | Working Example                                          |
| ------------------------------------------------------- | -------------------------------------------------------- |
| ![Broken Example](./resources/images/BrokenExample.png) | ![Broken Example](./resources/images/WorkingExample.png) |

&nbsp;

## Solution

### High Level

The solution to this problem is the use of a different token instead of the `GITHUB_TOKEN`. However, utilizing Personal Access Tokens (PAT) is not a secure method and should be avoided when possible. Instead, a GitHub App should be created and utilized.

### Creating a GitHub App [^3]

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

### Repo Configuration [^4]

- Go to the repo where **terraform-docs** will be used
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

With these 2 additions, the next time **terraform-docs** makes a commit, it will come from the new GitHub App. This will trigger the workflows to restart, evaluate the new commit, and maintain the status checks for the PR. An example PR is located in this repo here: #2

#### Repeated Actions

In this example, **terraform-docs** is the last step to run in the workflow. With this ordering, all jobs will be re-ran after **terraform-docs** makes it's commit, including the `on-push` and `on-pull-request` workflows. This behavior may not be desired depending on the tasks being ran during these previous steps. This is a trade-off with this solution, but can be worked around by relocating **terraform-docs** to an earlier step and utilizing _concurrency_ with the involved workflows[^5].

# Sources:

[^1]: https://terraform-docs.io/
[^2]: https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token
[^3]: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app
[^4]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions#example-workflow-authenticating-with-a-github-app
[^5]: https://docs.github.com/en/actions/using-jobs/using-concurrency#example-using-concurrency-to-cancel-any-in-progress-job-or-run
