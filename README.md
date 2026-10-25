# GitHub Actions OIDC to AWS Terraform starter

This starter creates a VPC with two public subnets in `ap-south-1` and a private S3 bucket with versioning, encryption, and public access blocked.

## High-level setup

1. Create an AWS IAM OIDC provider for `https://token.actions.githubusercontent.com` (audience `sts.amazonaws.com`) and an IAM role whose trust policy is scoped to this repository and deployment branch/environment.
2. Give that role only the AWS permissions required by the resources in this repository. For an actual team deployment, use a reviewed least-privilege policy and separate deployment roles by environment.
3. Add the role ARN as GitHub Actions repository or environment secret `AWS_ROLE_ARN`. Configure the `production` environment with deployment branch protection/required reviewers.
4. Configure Terraform state in a separately managed S3 backend with locking (or another supported remote backend). The bucket created by this configuration is an application bucket, not a Terraform state backend.
5. Initialize, review, plan, and apply. Protect `main` and require pull request review before changes can deploy.

## Low-level steps

### Bootstrap IAM OIDC (one-time, by an AWS administrator)

In AWS IAM, add an OpenID Connect identity provider with provider URL `https://token.actions.githubusercontent.com` and audience `sts.amazonaws.com`, unless it already exists in the account. Create an IAM role trusted by that provider. Restrict its trust policy `aud` to `sts.amazonaws.com` and its `sub` to your exact repository and protected deployment environment, for example `repo:YOUR_ORG/YOUR_REPO:environment:production`. Do not use a wildcard repository/organization subject. Keep the role permissions scoped to the resources and actions this stack needs; broad administrator permissions are not appropriate for production.

GitHub's `environment: production` job emits the environment-form subject. If you instead scope by branch, use `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main` and remove the environment field or align both settings. Do not mix the two subject patterns accidentally. The trust policy's `sub` claim is the critical repository/deployment boundary.

### Prepare the repository

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and set a globally unique bucket name. The real `.tfvars` is ignored by Git.
2. In GitHub repository Settings ? Environments, create `production`, restrict deployment branches to `main`, and consider required reviewers.
3. Add repository/environment secret `AWS_ROLE_ARN` with the role ARN.
4. Commit the files and open a pull request. The workflow runs format, validation, and plan on PRs; pushes to `main` apply the reviewed plan. Inspect workflow plans before merging.

### Local use

Use AWS IAM Identity Center or another short-lived developer credential flow, never put access keys in the repository. From the repository root:

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit bucket_name in terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

For Windows PowerShell, replace the copy command with `Copy-Item terraform.tfvars.example terraform.tfvars`.

## Important notes

- This VPC has public subnets and an Internet Gateway but no NAT Gateway, private subnets, or compute resources. Public subnet route does not expose anything by itself; add security groups and private networking before deploying workloads.
- `prevent_destroy = true` protects the bucket from accidental Terraform destruction. Remove it only after deliberate data-retention review.
- `.gitignore` does not protect secrets already committed; rotate any leaked credentials.
- Add a remote backend with encryption, versioning, and state locking before team use. Bootstrap that backend separately to avoid the initial state chicken-and-egg problem.
- Pin GitHub Actions to reviewed full commit SHAs for hardened supply-chain security. Keep action versions and Terraform/provider versions updated through review.