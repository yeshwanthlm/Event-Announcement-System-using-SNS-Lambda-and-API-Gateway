#!/bin/bash

# Script to update frontend files and invalidate CloudFront cache

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Updating frontend files...${NC}"

cd "$TERRAFORM_DIR"

# Get CloudFront distribution ID
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get S3 bucket name. Is the infrastructure deployed?"
    exit 1
fi

# Upload files to S3
echo "Uploading files to S3..."
aws s3 cp "$PROJECT_DIR/frontend/index.html" "s3://$BUCKET_NAME/index.html" --content-type "text/html"
aws s3 cp "$PROJECT_DIR/frontend/styles.css" "s3://$BUCKET_NAME/styles.css" --content-type "text/css"
aws s3 cp "$PROJECT_DIR/frontend/events.json" "s3://$BUCKET_NAME/events.json" --content-type "application/json"

echo -e "${GREEN}✓ Files uploaded to S3${NC}"

# Invalidate CloudFront cache
if [ -n "$CLOUDFRONT_ID" ]; then
    echo "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text
    echo -e "${GREEN}✓ CloudFront cache invalidation created${NC}"
    echo "Note: Cache invalidation takes 5-10 minutes to complete"
else
    echo "Warning: Could not get CloudFront distribution ID"
fi

echo -e "${GREEN}✓ Frontend update complete!${NC}"
