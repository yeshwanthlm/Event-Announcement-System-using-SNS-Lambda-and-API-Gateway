# Event Announcement System using SNS, Lambda, and API Gateway

A serverless event announcement system built with AWS services and managed entirely through Terraform. This project allows users to subscribe to event notifications via email and create new events that automatically notify all subscribers.

## Video Tutorial:
<img width="1920" height="1080" alt="Event Announcement System" src="https://github.com/user-attachments/assets/23a3c4a3-2be6-4d2f-b18a-ae762e7b81e5" />
Video link: https://youtu.be/_3g9SKlRIWk

## 🚀 Key Features

- **CloudFront CDN Integration**: Fast global content delivery with HTTPS
- **Automated Deployment Script**: One-command deployment with `./deploy.sh`
- **Smart Cache Management**: Automatic CloudFront cache invalidation
- **Interactive Log Viewer**: Easy debugging with `./deploy.sh logs`
- **Helper Scripts**: Quick frontend updates without full redeployment
- **Complete Infrastructure as Code**: Everything managed with Terraform

## Architecture
<img width="1281" height="540" alt="image" src="https://github.com/user-attachments/assets/725b9ea1-7820-4cb1-9e5a-bbfd8027f7b2" />

```
┌─────────────────────────────────────────────────────────────────┐
│                         End Users                                │
│                    (Web Browsers / Email)                        │
└────────────┬────────────────────────────────────┬───────────────┘
             │                                    │
             │ HTTPS                              │ Email
             ▼                                    ▼
    ┌─────────────────┐                  ┌──────────────┐
    │   CloudFront    │                  │  Amazon SNS  │
    │      (CDN)      │                  │   (Topic)    │
    └────────┬────────┘                  └──────▲───────┘
             │                                   │
             │ Origin                            │ Publish
             ▼                                   │
    ┌─────────────────┐                         │
    │   Amazon S3     │                         │
    │  (Static Site)  │                         │
    │  - index.html   │                         │
    │  - styles.css   │                         │
    │  - events.json  │◄────────────┐           │
    └─────────────────┘              │           │
                                     │ Update    │
             ┌───────────────────────┼───────────┤
             │                       │           │
             │ API Calls             │           │
             ▼                       │           │
    ┌─────────────────┐              │           │
    │  API Gateway    │              │           │
    │   (REST API)    │              │           │
    │  - /subscribe   │──────┐       │           │
    │  - /create-event│──┐   │       │           │
    └─────────────────┘  │   │       │           │
                         │   │       │           │
                         │   │       │           │
             ┌───────────┘   └───────┼───────────┘
             │                       │
             ▼                       ▼
    ┌──────────────────┐    ┌──────────────────┐
    │  Lambda Function │    │  Lambda Function │
    │   (Subscribe)    │    │  (Create Event)  │
    │                  │    │                  │
    │ - Subscribe user │    │ - Update S3      │
    │   to SNS topic   │    │ - Notify via SNS │
    └──────────────────┘    └──────────────────┘

    All managed by Terraform Infrastructure as Code
```

### Components

- **S3**: Hosts the static website frontend and stores event data
- **CloudFront**: CDN for fast global content delivery with HTTPS
- **SNS**: Manages email subscriptions and sends notifications
- **Lambda**: Two functions handle subscriptions and event creation
- **API Gateway**: REST API endpoints for frontend-backend communication
- **Terraform**: Infrastructure as Code for complete AWS resource management

## Features

- 📧 Email subscription system with SNS confirmation
- 🎉 Create and announce new events
- 🔔 Automatic email notifications to all subscribers
- 🌐 Static website hosting on S3
- ⚡ CloudFront CDN for fast global delivery with HTTPS
- 🚀 Fully automated infrastructure deployment with Terraform
- 🔧 Convenient deployment script for easy management

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Terraform installed (v1.0+)
- Git (optional, for version control)

## Project Structure

```
.
├── terraform/
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Terraform variables
│   ├── outputs.tf               # Terraform outputs
│   └── terraform.tfvars.example # Example variables file
├── lambda/
│   ├── subscribe.py            # Lambda function for subscriptions
│   └── create_event.py         # Lambda function for event creation
├── frontend/
│   ├── index.html              # Website frontend
│   ├── styles.css              # Website styling
│   └── events.json             # Event data storage
├── scripts/
│   └── update-frontend.sh      # Quick frontend updates
├── deploy.sh                   # Automated deployment script
└── README.md                   # Complete documentation
```

## Deployment Steps

### Quick Start (Automated Deployment) ⚡

The easiest way to deploy is using the automated deployment script:

```bash
# 1. Clone the repository (if using Git)
git clone <your-repo-url>
cd event-announcement-system

# 2. Configure your settings
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your unique bucket name

# 3. Run the deployment script
./deploy.sh
```

**The script automatically handles everything:**
- ✅ Checks all prerequisites (Terraform, AWS CLI, credentials)
- ✅ Initializes Terraform
- ✅ Shows deployment plan for review
- ✅ Deploys all infrastructure (S3, CloudFront, Lambda, API Gateway, SNS)
- ✅ Automatically updates frontend with API URLs
- ✅ Invalidates CloudFront cache
- ✅ Runs basic tests
- ✅ Displays all important URLs

**Total deployment time**: ~20-25 minutes (mostly CloudFront distribution setup)

### Manual Deployment (Step by Step)

If you prefer manual control:

#### 1. Clone and Setup

```bash
# Clone the repository (if using Git)
git clone <your-repo-url>
cd event-announcement-system
```

#### 2. Configure Terraform Variables

```bash
# Copy the example variables file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit terraform/terraform.tfvars with your values
# IMPORTANT: bucket_name must be globally unique
```

Example `terraform/terraform.tfvars`:
```hcl
aws_region            = "ap-south-1"
bucket_name           = "event-announcement-website-yourname-12345"
cloudfront_price_class = "PriceClass_100"  # Optional: PriceClass_All, PriceClass_200, PriceClass_100
```

#### 3. Initialize and Deploy with Terraform

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

Type `yes` when prompted to confirm the deployment.

#### 4. Get the Deployment URLs

After successful deployment, Terraform will output important URLs:

```bash
# View outputs (from terraform directory)
terraform output
```

You'll see:
- `cloudfront_url`: Your CloudFront CDN URL (use this for production)
- `website_url`: Your S3 website endpoint (direct access)
- `subscribe_endpoint`: API endpoint for subscriptions
- `create_event_endpoint`: API endpoint for creating events
- `sns_topic_arn`: SNS topic ARN
- `cloudfront_distribution_id`: CloudFront distribution ID

#### 5. Update Frontend with API URLs

After deployment, update the frontend with your actual API Gateway URL:

1. Note the `api_gateway_url` from Terraform outputs
2. Update `frontend/index.html` line 62:

```javascript
// Replace this line:
const API_BASE_URL = 'YOUR_API_GATEWAY_URL';

// With your actual API Gateway URL (without trailing slash):
const API_BASE_URL = 'https://xxxxxxxxxx.execute-api.ap-south-1.amazonaws.com/dev';
```

3. Re-upload the updated file to S3:

```bash
# Using AWS CLI (from project root)
aws s3 cp frontend/index.html s3://YOUR-BUCKET-NAME/index.html --content-type "text/html"

# Or use Terraform to re-apply (from terraform directory)
cd terraform
terraform apply -replace="aws_s3_object.index"

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id YOUR-DISTRIBUTION-ID --paths "/*"
```

#### 6. Access Your Website

Open the CloudFront URL from Terraform outputs in your browser:
```
https://xxxxxxxxxxxxx.cloudfront.net
```

Or use the S3 direct URL:
```
http://YOUR-BUCKET-NAME.s3-website.ap-south-1.amazonaws.com
```

## Testing the System

### Test Email Subscription

1. Click "Subscribe to Events" button on the website
2. Enter your email address
3. Check your email for AWS SNS confirmation
4. Click the confirmation link in the email

### Test Event Creation

1. Click "Create New Event" button
2. Fill in event details:
   - Event Title
   - Event Date
   - Event Description
3. Submit the form
4. All confirmed subscribers will receive an email notification
5. The event will appear on the website

### Manual Testing with AWS Console

#### Test Subscribe Lambda:
1. Go to AWS Lambda Console
2. Open `SubscribeToSNSFunction`
3. Create test event with:
```json
{
  "body": {
    "email": "test@example.com"
  }
}
```
4. Click "Test" and verify success

#### Test Create Event Lambda:
1. Go to AWS Lambda Console
2. Open `createEventFunction`
3. Create test event with:
```json
{
  "httpMethod": "POST",
  "body": "{\"title\":\"Tech Meetup\",\"date\":\"2024-12-01\",\"description\":\"A gathering of tech enthusiasts!\"}"
}
```
4. Click "Test" and verify:
   - Success response
   - `events.json` updated in S3
   - Email sent to subscribers

## Infrastructure Components

### S3 Bucket
- Hosts static website files
- Stores `events.json` for event data
- Public read access for website hosting

### SNS Topic
- Name: `EventAnnouncements`
- Manages email subscriptions
- Sends notifications for new events

### Lambda Functions

#### SubscribeToSNSFunction
- Runtime: Python 3.12
- Purpose: Subscribe users to SNS topic
- Permissions: SNS full access, CloudWatch logs

#### createEventFunction
- Runtime: Python 3.12
- Purpose: Create events and notify subscribers
- Permissions: S3 full access, SNS full access, CloudWatch logs

### API Gateway
- Name: `EventManagementAPI`
- Type: REST API
- Stage: `dev`
- Endpoints:
  - `POST /subscribe`: Subscribe to notifications
  - `POST /create-event`: Create new events
- CORS enabled for browser access

## Deployment Script Commands

The `deploy.sh` script provides convenient commands for managing your deployment:

```bash
# Deploy everything (initial deployment)
./deploy.sh deploy

# Update existing deployment
./deploy.sh update

# View Lambda logs interactively
./deploy.sh logs

# Check deployment status
./deploy.sh status

# Run basic tests
./deploy.sh test

# Destroy all infrastructure
./deploy.sh destroy

# Show help
./deploy.sh help
```

## Monitoring and Logs

### Using the Deployment Script

```bash
# Interactive log viewer
./deploy.sh logs
```

### Manual Log Access

View Lambda function logs in CloudWatch:

```bash
# Subscribe function logs
aws logs tail /aws/lambda/SubscribeToSNSFunction --follow

# Create event function logs
aws logs tail /aws/lambda/createEventFunction --follow
```

### CloudFront Monitoring

Monitor CloudFront performance in AWS Console:
- CloudFront → Distributions → Select your distribution → Monitoring

## Troubleshooting

### Common Issues

**Website not loading**
- CloudFront deployment takes 15-20 minutes initially
- Check status: `./deploy.sh status`
- Try direct S3 URL while CloudFront deploys

**Subscription not working**
- Check email spam folder for SNS confirmation
- Verify API URL in frontend: `grep API_BASE_URL frontend/index.html`
- View logs: `./deploy.sh logs`

**Events not creating**
- Check Lambda logs: `./deploy.sh logs`
- Verify S3 permissions: `aws s3 ls s3://YOUR-BUCKET`
- Test Lambda directly in AWS Console

**CloudFront showing old content**
- Invalidate cache: `./deploy.sh update`
- Wait 5-10 minutes for invalidation to complete

**API errors (CORS, 500, etc.)**
- Check browser console for specific errors
- Verify CORS configuration in API Gateway
- Review Lambda function logs

### Additional Troubleshooting Tips

**Lambda timeout errors**
```bash
# Increase timeout in terraform/main.tf
resource "aws_lambda_function" "subscribe" {
  timeout = 30  # Increase from default 3 seconds
}
```

**Terraform state issues**
```bash
# Refresh state
cd terraform
terraform refresh

# Force unlock if needed
terraform force-unlock LOCK-ID
```

**Cost monitoring**
- Check AWS Cost Explorer regularly
- Set up billing alerts
- Use PriceClass_100 for CloudFront to reduce costs

## Cost Considerations

This project uses AWS Free Tier eligible services:
- **S3**: First 5GB storage free
- **CloudFront**: 1TB data transfer out free (first 12 months), 10M HTTP/HTTPS requests free
- **Lambda**: 1M requests/month free
- **SNS**: 1,000 email notifications/month free
- **API Gateway**: 1M API calls/month free (first 12 months)

Estimated monthly cost after free tier: $1-10 depending on usage and traffic.

**CloudFront Pricing Classes:**
- `PriceClass_100`: USA, Canada, Europe (lowest cost)
- `PriceClass_200`: Above + Asia, Africa, Middle East
- `PriceClass_All`: All edge locations (highest performance)

## Cleanup

### Using the Deployment Script (Recommended)

```bash
# Automated cleanup
./deploy.sh destroy
```

### Manual Cleanup

To destroy all resources and avoid charges:

```bash
# Navigate to terraform directory
cd terraform

# Destroy all Terraform-managed resources
terraform destroy
```

Type `yes` when prompted to confirm deletion.

**Note**: This will permanently delete:
- S3 bucket and all files
- CloudFront distribution
- Lambda functions
- API Gateway
- SNS topic and subscriptions
- IAM roles and policies

## Security Best Practices

- Use least-privilege IAM policies in production
- Enable S3 bucket versioning for event data
- Implement API Gateway authentication for production
- Use AWS Secrets Manager for sensitive configuration
- Enable CloudTrail for audit logging
- Consider using AWS WAF for API protection

## Customization

### Change AWS Region
Edit `terraform/terraform.tfvars`:
```hcl
aws_region = "us-east-1"  # Change to your preferred region
```

### Change CloudFront Price Class
Edit `terraform/terraform.tfvars`:
```hcl
cloudfront_price_class = "PriceClass_All"  # For global distribution
```

### Modify Event Data Structure
Update `lambda/create_event.py` and `frontend/index.html` to add custom fields.

### Add Email Templates
Customize SNS message format in `lambda/create_event.py` line 35.

### Style Customization
Modify `frontend/styles.css` to match your branding.

### Add Custom Domain (Optional)
1. Register a domain in Route 53 or use existing domain
2. Request SSL certificate in ACM (us-east-1 region for CloudFront)
3. Add to `terraform/main.tf`:
```hcl
resource "aws_cloudfront_distribution" "website" {
  # ... existing config ...
  
  aliases = ["events.yourdomain.com"]
  
  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID"
    ssl_support_method  = "sni-only"
  }
}
```
4. Create Route 53 A record pointing to CloudFront distribution

## Helper Scripts

### Main Deployment Script (`deploy.sh`)

Comprehensive deployment automation:
- Checks prerequisites
- Deploys infrastructure
- Updates frontend automatically
- Manages CloudFront cache
- Provides interactive log viewing

### Frontend Update Script (`scripts/update-frontend.sh`)

Quick frontend updates without full redeployment:
```bash
# After editing frontend files
./scripts/update-frontend.sh
```

This script:
- Uploads updated files to S3
- Invalidates CloudFront cache
- Faster than full Terraform apply

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Amazon SNS Documentation](https://docs.aws.amazon.com/sns/)
- [Amazon CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

This project is open source and available for educational purposes.

## Support

For issues or questions:
1. Check CloudWatch logs for Lambda functions
2. Review Terraform plan output for configuration issues
3. Verify AWS service quotas and limits
4. Check AWS service health dashboard

---

**Built with ❤️ using AWS and Terraform**
