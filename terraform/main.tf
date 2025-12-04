terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# Upload frontend files
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("../frontend/index.html")
}

resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.website.id
  key          = "styles.css"
  source       = "../frontend/styles.css"
  content_type = "text/css"
  etag         = filemd5("../frontend/styles.css")
}

resource "aws_s3_object" "events" {
  bucket       = aws_s3_bucket.website.id
  key          = "events.json"
  source       = "../frontend/events.json"
  content_type = "application/json"
  etag         = filemd5("../frontend/events.json")
}

# SNS Topic
resource "aws_sns_topic" "event_announcements" {
  name = "EventAnnouncements"
}

# IAM Role for Subscribe Lambda
resource "aws_iam_role" "lambda_subscribe_role" {
  name = "LambdaSubscribeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_subscribe_sns" {
  role       = aws_iam_role.lambda_subscribe_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_subscribe_logs" {
  role       = aws_iam_role.lambda_subscribe_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Subscribe Lambda Function
data "archive_file" "subscribe_lambda" {
  type        = "zip"
  source_file = "../lambda/subscribe.py"
  output_path = "../lambda/subscribe.zip"
}

resource "aws_lambda_function" "subscribe" {
  filename         = data.archive_file.subscribe_lambda.output_path
  function_name    = "SubscribeToSNSFunction"
  role            = aws_iam_role.lambda_subscribe_role.arn
  handler         = "subscribe.lambda_handler"
  source_code_hash = data.archive_file.subscribe_lambda.output_base64sha256
  runtime         = "python3.12"

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.event_announcements.arn
    }
  }
}

# IAM Role for Create Event Lambda
resource "aws_iam_role" "lambda_create_event_role" {
  name = "EventCreationLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_create_event_s3" {
  role       = aws_iam_role.lambda_create_event_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_create_event_sns" {
  role       = aws_iam_role.lambda_create_event_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_create_event_logs" {
  role       = aws_iam_role.lambda_create_event_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create Event Lambda Function
data "archive_file" "create_event_lambda" {
  type        = "zip"
  source_file = "../lambda/create_event.py"
  output_path = "../lambda/create_event.zip"
}

resource "aws_lambda_function" "create_event" {
  filename         = data.archive_file.create_event_lambda.output_path
  function_name    = "createEventFunction"
  role            = aws_iam_role.lambda_create_event_role.arn
  handler         = "create_event.lambda_handler"
  source_code_hash = data.archive_file.create_event_lambda.output_base64sha256
  runtime         = "python3.12"

  environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.website.id
      SNS_TOPIC_ARN = aws_sns_topic.event_announcements.arn
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "event_api" {
  name        = "EventManagementAPI"
  description = "API for Event Announcement System"
}

# /subscribe resource
resource "aws_api_gateway_resource" "subscribe" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  parent_id   = aws_api_gateway_rest_api.event_api.root_resource_id
  path_part   = "subscribe"
}

resource "aws_api_gateway_method" "subscribe_post" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.event_api.id
  resource_id             = aws_api_gateway_resource.subscribe.id
  http_method             = aws_api_gateway_method.subscribe_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.subscribe.invoke_arn

  request_templates = {
    "application/json" = "{\"body\": $input.json('$')}"
  }
}

resource "aws_api_gateway_method_response" "subscribe_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "subscribe" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_post.http_method
  status_code = aws_api_gateway_method_response.subscribe_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.subscribe_lambda]
}

# CORS for /subscribe
resource "aws_api_gateway_method" "subscribe_options" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "subscribe_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = aws_api_gateway_method_response.subscribe_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.subscribe_options]
}

# /create-event resource
resource "aws_api_gateway_resource" "create_event" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  parent_id   = aws_api_gateway_rest_api.event_api.root_resource_id
  path_part   = "create-event"
}

resource "aws_api_gateway_method" "create_event_post" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.create_event.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_event_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.event_api.id
  resource_id             = aws_api_gateway_resource.create_event.id
  http_method             = aws_api_gateway_method.create_event_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_event.invoke_arn
}

# CORS for /create-event
resource "aws_api_gateway_method" "create_event_options" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.create_event.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "create_event_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = aws_api_gateway_method_response.create_event_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.create_event_options]
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway_subscribe" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.event_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_create_event" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_event.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.event_api.execution_arn}/*/*"
}

# API Deployment
resource "aws_api_gateway_deployment" "event_api" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.subscribe.id,
      aws_api_gateway_method.subscribe_post.id,
      aws_api_gateway_integration.subscribe_lambda.id,
      aws_api_gateway_resource.create_event.id,
      aws_api_gateway_method.create_event_post.id,
      aws_api_gateway_integration.create_event_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.subscribe_lambda,
    aws_api_gateway_integration.create_event_lambda,
    aws_api_gateway_integration_response.subscribe,
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.event_api.id
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  stage_name    = "dev"
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "OAI for Event Announcement System"
}

# Update S3 bucket policy for CloudFront
resource "aws_s3_bucket_policy" "website_cloudfront" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.website.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      },
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website,
    aws_cloudfront_origin_access_identity.website
  ]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Event Announcement System CDN"
  price_class         = var.cloudfront_price_class

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Cache behavior for events.json with shorter TTL
  ordered_cache_behavior {
    path_pattern     = "events.json"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 60
    max_ttl                = 300
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "Event Announcement System"
    Environment = "Production"
  }
}
