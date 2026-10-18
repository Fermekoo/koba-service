# koba-service

Terraform infrastructure for the Koba EKS cluster on AWS.

## Resources Provisioned

| Resource             | Details                                       |
|----------------------|-----------------------------------------------|
| VPC                  | `10.0.0.0/16`, DNS hostnames enabled          |
| Public Subnets (×2)  | Across 2 AZs, ELB-tagged for NLB             |
| Private Subnets (×2) | Across 2 AZs, internal-ELB tagged            |
| Internet Gateway     | Attached to VPC                               |
| NAT Gateway (×1)     | Single NAT in `public_1` (dev cost-saving)   |
| EKS Cluster          | v1.29, public + private endpoint access       |
| EKS Node Group       | `t3.medium`, 2 desired / 1 min / 4 max        |
| IAM Roles            | Cluster role + Node role with required policies |

## Local Setup

```bash
# Copy and edit vars
cp terraform.tfvars.example terraform.tfvars

# Init (with S3 backend)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=koba/terraform.tfstate" \
  -backend-config="region=us-east-1"

# Plan
terraform plan

# Apply
terraform apply
```

## CI/CD Pipelines

### terraform-plan (on PR)

Opens a PR → GitHub Actions runs `terraform plan` and posts the output as a PR comment.

### terraform-apply (manual dispatch)

Go to **Actions → Terraform Apply → Run workflow**, select environment (`dev` or `prod`), and click run.

## Required GitHub Secrets

| Secret            | Description                                    |
|-------------------|------------------------------------------------|
| `AWS_ROLE_ARN`    | IAM Role ARN for GitHub OIDC authentication   |
| `AWS_REGION`      | AWS region (e.g. `us-east-1`)                 |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state            |
| `TF_STATE_KEY`    | S3 key for state file (e.g. `koba/terraform.tfstate`) |

## Post-Setup Steps

### 1. Create S3 State Bucket

```bash
aws s3api create-bucket \
  --bucket koba-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket koba-terraform-state \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket koba-terraform-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### 2. Set Up GitHub OIDC in AWS IAM

Create an OIDC identity provider for GitHub Actions in your AWS account:

```
OIDC provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

Create an IAM role with trust policy scoped to this repo (replace placeholders):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/koba-service:*"
        }
      }
    }
  ]
}
```

Attach the following policies to the role:
- `AmazonEKSClusterPolicy`
- `AmazonVPCFullAccess`
- `IAMFullAccess` (or a scoped policy)
- `AmazonS3FullAccess` (scoped to state bucket)

### 3. Configure kubectl After Apply

```bash
aws eks --region us-east-1 update-kubeconfig --name koba-eks-cluster
kubectl get nodes
```

### 4. Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 5. Install AWS Load Balancer Controller

Required for the NLB Service in `koba-config`. See the [official docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html).

## Notes

- **NAT Gateway**: Single NAT gateway used for dev (cost-saving). For production, provision one NAT per AZ.
- **State locking**: Add a DynamoDB table for state locking in production environments.
