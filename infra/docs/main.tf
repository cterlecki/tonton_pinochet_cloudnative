locals {
  name = "${var.team}-cloudnative-${var.environment}"
}

# Private bucket: only CloudFront reads it (origin access control).
resource "aws_s3_bucket" "docs" {
  bucket = "${local.name}-docs"
  # Site content is rebuilt by CI from docs/, nothing here is worth keeping.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "docs" {
  name                              = "${local.name}-docs"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "docs" {
  enabled             = true
  comment             = "${local.name} documentation site"
  default_root_object = "index.html"
  http_version        = "http2and3"
  # shortcut: cheapest price class (US/EU edges only), switch to PriceClass_All for worldwide latency.
  price_class = "PriceClass_100"

  origin {
    origin_id                = "docs"
    domain_name              = aws_s3_bucket.docs.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.docs.id
  }

  default_cache_behavior {
    target_origin_id       = "docs"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true
  }

  # The bucket is private: a missing key answers 403. MkDocs builds 404.html.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # shortcut: default *.cloudfront.net certificate, add an ACM cert + alias for a custom domain.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "docs" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.docs.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.docs.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "docs" {
  bucket = aws_s3_bucket.docs.id
  policy = data.aws_iam_policy_document.docs.json

  depends_on = [aws_s3_bucket_public_access_block.docs]
}
