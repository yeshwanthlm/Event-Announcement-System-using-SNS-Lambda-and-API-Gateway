output "website_url" {
  description = "S3 website endpoint URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "sns_topic_arn" {
  description = "SNS Topic ARN"
  value       = aws_sns_topic.event_announcements.arn
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.dev.invoke_url
}

output "subscribe_endpoint" {
  description = "Subscribe endpoint URL"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/subscribe"
}

output "create_event_endpoint" {
  description = "Create event endpoint URL"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/create-event"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website.id
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_url" {
  description = "CloudFront distribution URL (use this for production)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}
