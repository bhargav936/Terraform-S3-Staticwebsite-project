output "website_bucket_name" {
  value = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "site_url" {
  value = "https://${var.domain_name}"
}

output "www_site_url" {
  value = "https://www.${var.domain_name}"
}

output "acm_certificate_arn" {
  value = aws_acm_certificate_validation.cert.certificate_arn
}