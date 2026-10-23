output "bucket" {
  description = "Bucket the CI syncs the built site into."
  value       = aws_s3_bucket.docs.bucket
}

output "distribution_id" {
  description = "CloudFront distribution id, for cache invalidation after a sync."
  value       = aws_cloudfront_distribution.docs.id
}

output "url" {
  description = "Public site URL."
  value       = "https://${aws_cloudfront_distribution.docs.domain_name}"
}
