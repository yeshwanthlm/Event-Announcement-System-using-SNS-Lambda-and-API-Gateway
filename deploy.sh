#!/bin/bash

# Event Announcement System - Automated Deployment Script
# This script handles the complete deployment process including CloudFront CDN

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
LAMBDA_DIR="$SCRIPT_DIR/lambda"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ${1}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        echo "Visit: https://www.terraform.io/downloads"
        exit 1
    fi
    print_success "Terraform is installed: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        echo "Visit: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_success "AWS CLI is installed: $(aws --version | cut -d' ' -f1)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured properly."
        echo "Run: aws configure"
        exit 1
    fi
    print_success "AWS credentials are configured"
    
    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
        print_error "Please edit terraform/terraform.tfvars with your configuration and run again."
        exit 1
    fi
    print_success "terraform.tfvars exists"
}

# Function to initialize Terraform
init_terraform() {
    print_header "Initializing Terraform"
    cd "$TERRAFORM_DIR"
    terraform init
    print_success "Terraform initialized"
}

# Function to plan deployment
plan_deployment() {
    print_header "Planning Deployment"
    cd "$TERRAFORM_DIR"
    terraform plan -out=tfplan
    print_success "Deployment plan created"
}

# Function to apply deployment
apply_deployment() {
    print_header "Applying Deployment"
    cd "$TERRAFORM_DIR"
    terraform apply tfplan
    rm -f tfplan
    print_success "Infrastructure deployed"
}

# Function to get outputs
get_outputs() {
    print_header "Deployment Information"
    cd "$TERRAFORM_DIR"
    
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain 2>/dev/null || echo "")
    S3_URL=$(terraform output -raw website_url 2>/dev/null || echo "")
    SUBSCRIBE_ENDPOINT=$(terraform output -raw subscribe_endpoint 2>/dev/null || echo "")
    CREATE_EVENT_ENDPOINT=$(terraform output -raw create_event_endpoint 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null || echo "")
    
    echo -e "${GREEN}📊 Deployment Outputs:${NC}"
    echo -e "  ${CYAN}CloudFront URL (Production):${NC} ${GREEN}$CLOUDFRONT_URL${NC}"
    echo -e "  ${BLUE}S3 Website URL (Direct):${NC} $S3_URL"
    echo -e "  ${BLUE}API Gateway URL:${NC} $API_URL"
    echo -e "  ${BLUE}Subscribe Endpoint:${NC} $SUBSCRIBE_ENDPOINT"
    echo -e "  ${BLUE}Create Event Endpoint:${NC} $CREATE_EVENT_ENDPOINT"
    echo -e "  ${BLUE}CloudFront Distribution ID:${NC} $CLOUDFRONT_ID"
    echo -e "  ${BLUE}S3 Bucket Name:${NC} $BUCKET_NAME"
    echo -e "  ${BLUE}SNS Topic ARN:${NC} $SNS_TOPIC_ARN"
    
    # Export for use in other functions
    export API_URL CLOUDFRONT_URL CLOUDFRONT_DOMAIN CLOUDFRONT_ID BUCKET_NAME SNS_TOPIC_ARN S3_URL
}

# Function to update frontend with API URL
update_frontend() {
    print_header "Updating Frontend Configuration"
    
    if [ -z "$API_URL" ]; then
        print_error "API URL not found. Skipping frontend update."
        return 1
    fi
    
    # Update index.html with API URL
    sed -i.bak "s|const API_BASE_URL = '.*';|const API_BASE_URL = '$API_URL';|g" "$FRONTEND_DIR/index.html"
    rm -f "$FRONTEND_DIR/index.html.bak"
    
    print_success "Frontend updated with API URL: $API_URL"
    
    # Re-upload to S3
    print_info "Re-uploading index.html to S3..."
    cd "$TERRAFORM_DIR"
    terraform apply -replace="aws_s3_object.index" -auto-approve
    
    print_success "Frontend re-deployed to S3"
}

# Function to invalidate CloudFront cache
invalidate_cloudfront() {
    print_header "Invalidating CloudFront Cache"
    
    if [ -z "$CLOUDFRONT_ID" ]; then
        print_warning "CloudFront Distribution ID not found. Skipping cache invalidation."
        return 0
    fi
    
    print_info "Creating CloudFront invalidation for all files..."
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$INVALIDATION_ID" ]; then
        print_success "CloudFront invalidation created: $INVALIDATION_ID"
        print_info "Cache invalidation typically takes 5-10 minutes to complete."
        print_info "You can check status with: aws cloudfront get-invalidation --distribution-id $CLOUDFRONT_ID --id $INVALIDATION_ID"
    else
        print_warning "Failed to create CloudFront invalidation. You may need to wait or invalidate manually."
    fi
}

# Function to check CloudFront distribution status
check_cloudfront_status() {
    print_header "Checking CloudFront Distribution Status"
    
    if [ -z "$CLOUDFRONT_ID" ]; then
        print_warning "CloudFront Distribution ID not found."
        return 1
    fi
    
    print_info "Fetching CloudFront distribution status..."
    STATUS=$(aws cloudfront get-distribution \
        --id "$CLOUDFRONT_ID" \
        --query 'Distribution.Status' \
        --output text 2>/dev/null || echo "Unknown")
    
    if [ "$STATUS" = "Deployed" ]; then
        print_success "CloudFront distribution is fully deployed and ready!"
    elif [ "$STATUS" = "InProgress" ]; then
        print_warning "CloudFront distribution is still deploying (Status: $STATUS)"
        print_info "This typically takes 15-20 minutes for initial deployment."
        print_info "You can use the S3 URL in the meantime: $S3_URL"
    else
        print_warning "CloudFront distribution status: $STATUS"
    fi
    
    echo ""
}

# Function to run tests
run_tests() {
    print_header "Running Basic Tests"
    
    cd "$TERRAFORM_DIR"
    
    local test_passed=0
    local test_failed=0
    
    # Test Lambda functions exist
    print_info "Checking Lambda functions..."
    if aws lambda get-function --function-name SubscribeToSNSFunction &> /dev/null; then
        print_success "SubscribeToSNSFunction exists"
        ((test_passed++))
    else
        print_error "SubscribeToSNSFunction not found"
        ((test_failed++))
    fi
    
    if aws lambda get-function --function-name createEventFunction &> /dev/null; then
        print_success "createEventFunction exists"
        ((test_passed++))
    else
        print_error "createEventFunction not found"
        ((test_failed++))
    fi
    
    # Test S3 bucket
    if [ -n "$BUCKET_NAME" ]; then
        print_info "Checking S3 bucket..."
        if aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
            print_success "S3 bucket accessible: $BUCKET_NAME"
            ((test_passed++))
            
            # Check if files exist
            if aws s3 ls "s3://$BUCKET_NAME/index.html" &> /dev/null; then
                print_success "index.html uploaded"
                ((test_passed++))
            else
                print_error "index.html not found in S3"
                ((test_failed++))
            fi
        else
            print_error "S3 bucket not accessible"
            ((test_failed++))
        fi
    fi
    
    # Test CloudFront
    if [ -n "$CLOUDFRONT_ID" ]; then
        print_info "Checking CloudFront distribution..."
        STATUS=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.Status' --output text 2>/dev/null || echo "Unknown")
        if [ "$STATUS" = "Deployed" ]; then
            print_success "CloudFront distribution is deployed"
            ((test_passed++))
        elif [ "$STATUS" = "InProgress" ]; then
            print_warning "CloudFront distribution is still deploying"
        else
            print_warning "CloudFront status: $STATUS"
        fi
    fi
    
    # Test SNS topic
    if [ -n "$SNS_TOPIC_ARN" ]; then
        print_info "Checking SNS topic..."
        if aws sns get-topic-attributes --topic-arn "$SNS_TOPIC_ARN" &> /dev/null; then
            print_success "SNS topic exists"
            ((test_passed++))
        else
            print_error "SNS topic not accessible"
            ((test_failed++))
        fi
    fi
    
    # Test API Gateway
    if [ -n "$API_URL" ]; then
        print_info "Testing API Gateway endpoint..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/subscribe" -X OPTIONS 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            print_success "API Gateway is responding (HTTP $HTTP_CODE)"
            ((test_passed++))
        else
            print_warning "API Gateway returned HTTP $HTTP_CODE (may need time to propagate)"
        fi
    fi
    
    # Test summary
    echo ""
    print_info "Test Summary: ${GREEN}$test_passed passed${NC}, ${RED}$test_failed failed${NC}"
    echo ""
}

# Function to show deployment summary
show_summary() {
    print_header "Deployment Complete! 🎉"
    
    echo -e "${GREEN}Your Event Announcement System is now live!${NC}\n"
    
    # Check CloudFront status
    check_cloudfront_status
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🌐 Access Your Website:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "   ${MAGENTA}Production (CloudFront):${NC} ${GREEN}$CLOUDFRONT_URL${NC}"
    echo -e "   ${BLUE}Direct (S3):${NC}             ${YELLOW}$S3_URL${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "   ${GREEN}1.${NC} Open the CloudFront URL in your browser"
    echo -e "   ${GREEN}2.${NC} Click 'Subscribe to Events' to test email subscription"
    echo -e "   ${GREEN}3.${NC} Check your email and confirm the AWS SNS subscription"
    echo -e "   ${GREEN}4.${NC} Create a test event to verify notifications work\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧 Useful Commands:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "   View logs:           ${YELLOW}./deploy.sh logs${NC}"
    echo -e "   Update deployment:   ${YELLOW}./deploy.sh update${NC}"
    echo -e "   Check status:        ${YELLOW}./deploy.sh status${NC}"
    echo -e "   Run tests:           ${YELLOW}./deploy.sh test${NC}"
    echo -e "   Update frontend:     ${YELLOW}./scripts/update-frontend.sh${NC}"
    echo -e "   Destroy all:         ${YELLOW}./deploy.sh destroy${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "   Complete Guide:      ${YELLOW}README.md${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}💡 Important Notes:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "   • CloudFront deployment takes 15-20 minutes initially"
    echo -e "   • Use S3 URL if CloudFront is still deploying"
    echo -e "   • Check spam folder for SNS confirmation emails"
    echo -e "   • Frontend is pre-configured with API endpoints\n"
}

# Function to view logs
view_logs() {
    print_header "Viewing Lambda Logs"
    
    echo -e "${BLUE}Select which logs to view:${NC}"
    echo "1) Subscribe Lambda"
    echo "2) Create Event Lambda"
    echo "3) Both"
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1)
            print_info "Tailing SubscribeToSNSFunction logs..."
            aws logs tail /aws/lambda/SubscribeToSNSFunction --follow
            ;;
        2)
            print_info "Tailing createEventFunction logs..."
            aws logs tail /aws/lambda/createEventFunction --follow
            ;;
        3)
            print_info "Opening both log streams..."
            echo "Opening Subscribe Lambda logs in new terminal..."
            osascript -e 'tell app "Terminal" to do script "aws logs tail /aws/lambda/SubscribeToSNSFunction --follow"' 2>/dev/null || \
            gnome-terminal -- bash -c "aws logs tail /aws/lambda/SubscribeToSNSFunction --follow" 2>/dev/null || \
            print_warning "Could not open new terminal. Please run manually."
            
            print_info "Tailing createEventFunction logs..."
            aws logs tail /aws/lambda/createEventFunction --follow
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
}

# Function to update deployment
update_deployment() {
    print_header "Updating Deployment"
    
    cd "$TERRAFORM_DIR"
    
    print_info "Applying Terraform changes..."
    terraform apply -auto-approve
    
    get_outputs
    update_frontend
    invalidate_cloudfront
    check_cloudfront_status
    
    print_success "Deployment updated successfully!"
    echo ""
    print_info "CloudFront URL: $CLOUDFRONT_URL"
    print_info "Note: Changes may take 5-10 minutes to propagate through CloudFront"
}

# Function to save deployment info
save_deployment_info() {
    print_header "Saving Deployment Information"
    
    local INFO_FILE="$SCRIPT_DIR/deployment-info.txt"
    
    cat > "$INFO_FILE" << EOF
Event Announcement System - Deployment Information
Generated: $(date)

URLS:
=====
CloudFront URL (Production): $CLOUDFRONT_URL
S3 Website URL (Direct):     $S3_URL
API Gateway URL:             $API_URL

Endpoints:
==========
Subscribe:    $SUBSCRIBE_ENDPOINT
Create Event: $CREATE_EVENT_ENDPOINT

AWS Resources:
==============
S3 Bucket:              $BUCKET_NAME
CloudFront Distribution: $CLOUDFRONT_ID
SNS Topic:              $SNS_TOPIC_ARN

Quick Commands:
===============
View logs:        ./deploy.sh logs
Update:           ./deploy.sh update
Check status:     ./deploy.sh status
Destroy:          ./deploy.sh destroy

Documentation:
==============
README.md
QUICKSTART.md
TROUBLESHOOTING.md
DEPLOYMENT_CHECKLIST.md
EOF
    
    print_success "Deployment info saved to: $INFO_FILE"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_header "Destroying Infrastructure"
    
    print_warning "This will destroy ALL resources created by Terraform!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    terraform destroy
    
    print_success "Infrastructure destroyed"
}

# Function to show status
show_status() {
    print_header "Deployment Status"
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No deployment found. Run './deploy.sh' to deploy."
        exit 0
    fi
    
    terraform show
}

# Main script logic
main() {
    case "${1:-deploy}" in
        deploy)
            check_prerequisites
            init_terraform
            plan_deployment
            
            print_warning "Review the plan above. Do you want to proceed?"
            read -p "Type 'yes' to continue: " confirm
            if [ "$confirm" != "yes" ]; then
                print_info "Deployment cancelled"
                exit 0
            fi
            
            apply_deployment
            get_outputs
            update_frontend
            invalidate_cloudfront
            run_tests
            save_deployment_info
            show_summary
            ;;
        update)
            update_deployment
            ;;
        logs)
            view_logs
            ;;
        status)
            show_status
            ;;
        destroy)
            destroy_infrastructure
            ;;
        test)
            get_outputs
            run_tests
            ;;
        cloudfront)
            get_outputs
            check_cloudfront_status
            ;;
        info)
            get_outputs
            save_deployment_info
            cat "$SCRIPT_DIR/deployment-info.txt"
            ;;
        help|--help|-h)
            echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
            echo -e "${BLUE}Event Announcement System - Deployment Script${NC}"
            echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${BLUE}Usage:${NC} ./deploy.sh [command]"
            echo ""
            echo -e "${BLUE}Commands:${NC}"
            echo -e "  ${GREEN}deploy${NC}      - Deploy the complete infrastructure (default)"
            echo -e "  ${GREEN}update${NC}      - Update existing deployment"
            echo -e "  ${GREEN}logs${NC}        - View Lambda function logs interactively"
            echo -e "  ${GREEN}status${NC}      - Show current deployment status"
            echo -e "  ${GREEN}test${NC}        - Run basic tests on deployed resources"
            echo -e "  ${GREEN}cloudfront${NC}  - Check CloudFront distribution status"
            echo -e "  ${GREEN}info${NC}        - Display and save deployment information"
            echo -e "  ${GREEN}destroy${NC}     - Destroy all infrastructure"
            echo -e "  ${GREEN}help${NC}        - Show this help message"
            echo ""
            echo -e "${BLUE}Examples:${NC}"
            echo -e "  ./deploy.sh              # Initial deployment"
            echo -e "  ./deploy.sh update       # Update after changes"
            echo -e "  ./deploy.sh logs         # View Lambda logs"
            echo -e "  ./deploy.sh cloudfront   # Check CDN status"
            echo ""
            echo -e "${BLUE}Documentation:${NC}"
            echo -e "  README.md                # Complete guide with all information"
            echo ""
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Run './deploy.sh help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
