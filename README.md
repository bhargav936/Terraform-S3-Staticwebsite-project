# S3 Static Website with CloudFront, ACM & Route 53

Terraform module that provisions a fully HTTPS-enabled static website on AWS:
a private S3 bucket served through CloudFront (via Origin Access Control),
secured with an ACM certificate, and routed with Route 53 alias records for
both the apex domain and `www` subdomain.

## Architecture

```
Route 53 (apex + www A-alias records)
        │
        ▼
CloudFront Distribution  ──uses──  ACM Certificate (us-east-1, DNS-validated)
        │
        ▼  (Origin Access Control)
S3 Bucket (private, public access fully blocked)
```

- **S3** — stores `index.html` / `error.html`, all public access blocked
- **CloudFront** — public entry point, HTTPS only, OAC-signed requests to S3
- **ACM** — DNS-validated wildcard certificate, must live in `us-east-1`
- **Route 53** — hosted zone lookup + DNS validation records + alias records

## Prerequisites

- Terraform `>= 1.5.0`
- AWS provider `~> 6.0`
- An existing Route 53 public hosted zone for your domain
- An AWS CLI named profile with permissions for ACM, CloudFront, S3, Route 53
- Local `www/index.html` and `www/error.html` files in the module directory

## File Structure

```
.
├── providers.tf     # AWS provider + us-east-1 alias for ACM
├── variables.tf     # Input variables
├── main.tf          # ACM, S3, CloudFront, Route 53 resources
├── outputs.tf        # Useful outputs (URLs, distribution ID, cert ARN)
└── www/
    ├── index.html
    └── error.html
```

## Usage

```bash
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan
```

After apply, the site is reachable at the `site_url` and `www_site_url`
outputs. Initial CloudFront propagation can take several minutes.

## Variables

| Name           | Description                          | Default                                  |
|----------------|---------------------------------------|-------------------------------------------|
| `aws_region`   | Region for S3 / Route 53 resources    | `us-east-1`                               |
| `aws_profile`  | Named AWS CLI profile to use          | `Terraform`                               |
| `Environment`  | Environment tag                       | `Dev`                                     |
| `default-tags` | Map of default resource tags          | see `variables.tf`                        |
| `domain_name`  | Root domain name (must have a public Route 53 hosted zone) | `254103026944.realhandsonlabs.net` |

## Outputs

| Name                          | Description                          |
|-------------------------------|----------------------------------------|
| `website_bucket_name`         | S3 bucket name                        |
| `cloudfront_distribution_id`  | CloudFront distribution ID            |
| `cloudfront_domain_name`      | CloudFront default domain name        |
| `site_url`                    | `https://<domain_name>`               |
| `www_site_url`                | `https://www.<domain_name>`           |
| `acm_certificate_arn`         | Validated ACM certificate ARN         |

## Important: `us-east-1` provider must match your main profile

ACM certificates used by CloudFront must be requested in `us-east-1`
regardless of your main region, so this module declares an aliased provider:

```hcl
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}
```

**The `profile` argument here is required.** If omitted, this provider
silently falls back to your default AWS CLI credentials, which may resolve
to a *different AWS account* than your main provider. CloudFront cannot
attach an ACM certificate from another account — this produces:

```
Error: creating CloudFront Distribution: operation error CloudFront:
CreateDistributionWithTags, ... InvalidViewerCertificate: The specified
SSL certificate doesn't exist, isn't in us-east-1 region, isn't valid,
or doesn't include a valid certificate chain.
```

even when the certificate itself shows `Status: ISSUED`. Always verify:

```bash
aws sts get-caller-identity --profile <your-profile>
aws sts get-caller-identity   # default credentials
```

Both must return the **same** `Account` ID.

## Troubleshooting

**`InvalidViewerCertificate` on `aws_cloudfront_distribution` creation**
1. Confirm `aliases` on the distribution matches the ACM cert's domain + SANs.
2. Confirm the cert is `ISSUED`:
   ```bash
   aws acm describe-certificate --certificate-arn <arn> --region us-east-1 \
     --query "Certificate.{Status:Status,Validations:DomainValidationOptions[*].ValidationStatus}"
   ```
3. Confirm the cert's account matches your default provider's account (see above).
4. If the cert was created in the wrong account, remove it from state and
   recreate rather than trying to reconcile it:
   ```bash
   terraform state rm aws_acm_certificate.cert
   terraform state rm aws_acm_certificate_validation.cert
   terraform state rm 'aws_route53_record.cert_validation["<domain>"]'
   terraform state rm 'aws_route53_record.cert_validation["*.<domain>"]'
   terraform apply
   ```

**403 errors on missing pages**
S3 origins behind CloudFront return `403`, not `404`, for missing objects
since the bucket is fully private. This module maps both codes to
`/error.html` via `custom_error_response` blocks.

## Notes

- `force_destroy = true` on the S3 bucket allows `terraform destroy` to
  remove non-empty buckets — disable this for production use.
- The distribution uses `PriceClass_All` by default; adjust the CloudFront
  resource if you want to limit edge locations for cost control.
- The ACM certificate uses `create_before_destroy` so certificate rotation
  won't cause a brief outage.

## License

Add a license of your choice (e.g. MIT) if this repository is public.
