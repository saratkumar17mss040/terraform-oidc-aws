# GitHub Actions to AWS with OIDC

A short setup guide for provisioning the ap-south-1 Terraform example from GitHub Actions without storing long-lived AWS access keys.

## How authentication works

The workflow requests a short-lived OIDC token from GitHub. AWS checks the token's audience, repository, `production` environment, and `main` ref against the IAM role trust policy. If they match, AWS STS gives the job temporary credentials. The role's permissions policy controls what those credentials can do.

## High-level setup

1. Create a GitHub repository and add the Terraform configuration and workflow.
2. Add GitHub as an OIDC identity provider in AWS IAM.
3. Create an IAM role with a trust policy restricted to this repository's `production` environment and `main` branch.
4. Give the role only the AWS permissions required by the Terraform resources.
5. Protect the GitHub `production` environment, add the role ARN as an environment secret, and add the S3 bucket name as an environment variable.
6. Push to `main` or manually run the workflow from `main`. Approve the production deployment when prompted.

## Detailed setup

### 1. Prepare the GitHub repository

Add the Terraform files, `.gitignore`, and `.github/workflows/terraform.yml`. The workflow needs:

```yaml
permissions:
  contents: read
  id-token: write
```

`id-token: write` allows GitHub Actions to request the OIDC token; it does not grant AWS permissions by itself.

The workflow uses the `production` environment, runs `terraform init`, format check, validate, and plan, and applies on a push or manual dispatch from `main`. The environment's required reviewer must approve before its job proceeds.

### 2. Configure the AWS OIDC provider

In AWS IAM, create an identity provider (once per AWS account) with:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

### 3. Create and scope the IAM role

Create a role for **Web identity** using the GitHub provider. In its trust relationship, restrict `aud`, `sub`, and `ref`. Replace all placeholders with the actual account and GitHub IDs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:OWNER@OWNER_ID/REPOSITORY@REPOSITORY_ID:environment:production",
          "token.actions.githubusercontent.com:ref": "refs/heads/main"
        }
      }
    }
  ]
}
```

GitHub uses the ID-inclusive subject format for repositories created after July 15, 2026, or opted into immutable subjects. Older repositories may use `repo:OWNER/REPOSITORY:environment:production`; use the exact format your repository emits. Do not use wildcards for the repository or branch.

### 4. Grant Terraform permissions

Attach an identity-based permissions policy that allows the required VPC and S3 operations. Scope S3 permissions to the exact bucket ARN and include `s3:ListBucket` for bucket checks. Avoid broad administrator permissions for real deployments.

A permissions boundary is only a ceiling; it does not grant access. The effective role must be allowed by both its permissions policy and its boundary. If a boundary is used, it must include the VPC and S3 actions the stack needs.

### 5. Protect the GitHub production environment

In **Settings ? Environments ? production**:

- Limit deployment branches and tags to `main`.
- Add a required reviewer.

Add the role ARN as an environment secret named `AWS_ROLE_ARN`. Add the non-sensitive bucket name as an environment variable named `S3_BUCKET_NAME`. The workflow maps it to Terraform's `TF_VAR_bucket_name` variable.

### 6. Run the workflow

Push the configuration to `main`, or use **Actions ? Terraform ? Run workflow** and select `main`. Approve the production environment review when requested. Review the plan before allowing apply.

Because the trust policy requires `refs/heads/main`, pull request runs from other refs cannot assume the AWS role. Keep validation steps separate from AWS-authenticated deployment steps if pull request checks should pass without AWS credentials.

## Terraform state: important

The current workflow uses Terraform's local backend. GitHub-hosted runners are temporary, so state on a runner is lost after the job. A later run may think resources are new and try to create them again (for example, S3 can return `BucketAlreadyOwnedByYou`).

Before repeated or production deployments, configure a persistent remote backend (for example, a separate S3 state bucket with versioning and S3 lockfile locking). The backend bucket must exist before Terraform can initialize it, and the role needs backend state and lockfile permissions. If resources were already created without saved state, import them into the persistent state before applying again.

## Useful repository files

- `.gitignore` — excludes local state, `.terraform/`, plans, and real `.tfvars` files.
- `terraform.tfvars.example` — documents required local input without committing local values.
- `.terraform.lock.hcl` — commit this provider dependency lock file after `terraform init`.
- `.github/workflows/terraform.yml` — OIDC authentication and CI/CD workflow.
- Remote backend configuration — needed for persistent state before ongoing use.

Never commit AWS access keys, real `terraform.tfvars`, or Terraform state files.

## References

- [GitHub OIDC reference](https://docs.github.com/en/actions/reference/security/oidc)
- [GitHub: configure OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [AWS IAM: GitHub OIDC role setup](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)