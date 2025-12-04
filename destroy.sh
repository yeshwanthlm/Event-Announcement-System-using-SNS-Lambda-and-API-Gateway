#!/bin/bash

# Event Announcement System - Destruction Script
# This script safely destroys all AWS infrastructure

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
    echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ${1}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}\n"
}

# Function to check if deployment exists
check_deployment() {
    print_header "Checking Deployment Status"
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found!"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No Terraform state found. Nothing to destroy."
        exit 0
    fi
    
    print_success "Deployment found"
}

# Function to show what will be destroyed
show_resources() {
    print_header "Resources to be Destroyed"
    
    cd "$TERRAFORM_DIR"
    
    print_info "Fetching resource list..."
    echo ""
    
    # Get outputs if available
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "N/A")
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "N/A")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "N/A")
    
    echo -e "${YELLOW}The following resources will be PERMANENTLY DELETED:${NC}\n"
    
    echo -e "${RED}AWS Resources:${NC}"
    echo -e "  • S3 Bucket: ${MAGENTA}$S3_BUCKET${NC}"
    echo -e "  • CloudFront Distribution: ${MAGENTA}$CLOUDFRONT_ID${NC}"
    echo -e "  • Lambda Functions: ${MAGENTA}SubscribeToSNSFunction, createEventFunction${NC}"
    echo -e "  • API Gateway: ${MAGENTA}EventManagementAPI${NC}"
    echo -e "  • SNS Topic: ${MAGENTA}EventAnnouncements${NC}"
    echo -e "  • IAM Roles and Policies"
    echo -e "  • CloudWatch Log Groups"
    
    echo ""
    echo -e "${RED}Data Loss:${NC}"
    echo -e "  • All website files in S3"
    echo -e "  • All event data (events.json)"
    echo -e "  • All email subscriptions"
    echo -e "  • All CloudWatch logs"
    
    echo ""
    echo -e "${YELLOW}Website URL that will stop working:${NC}"
    echo -e "  • ${MAGENTA}$CLOUDFRONT_URL${NC}"
    
    echo ""
}

# Function to backup important data
backup_data() {
    print_header "Backing Up Important Data"
    
    cd "$TERRAFORM_DIR"
    
    BACKUP_DIR="$SCRIPT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    print_info "Creating backup in: $BACKUP_DIR"
    
    # Backup Terraform outputs
    if terraform output > "$BACKUP_DIR/terraform-outputs.txt" 2>/dev/null; then
        print_success "Terraform outputs saved"
    fi
    
    # Backup Terraform state
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "$BACKUP_DIR/terraform.tfstate.backup"
        print_success "Terraform state backed up"
    fi
    
    # Backup events.json from S3
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ]; then
        if aws s3 cp "s3://$S3_BUCKET/events.json" "$BACKUP_DIR/events.json" 2>/dev/null; then
            print_success "Events data backed up from S3"
        else
            print_warning "Could not backup events.json from S3"
        fi
    fi
    
    # Save deployment info
    cat > "$BACKUP_DIR/deployment-info.txt" << EOF
Event Announcement System - Backup
Created: $(date)

This backup was created before destroying the infrastructure.

Original Resources:
===================
CloudFront URL: $CLOUDFRONT_URL
S3 Bucket: $S3_BUCKET
CloudFront Distribution ID: $CLOUDFRONT_ID

To restore this deployment:
1. Review terraform.tfstate.backup
2. Restore events.json to S3 after redeployment
3. Run ./deploy.sh to create new infrastructure
EOF
    
    print_success "Backup completed: $BACKUP_DIR"
    echo ""
}

# Function to confirm destruction
confirm_destruction() {
    print_header "Confirmation Required"
    
    echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                   ║${NC}"
    echo -e "${RED}║           ⚠️  DESTRUCTIVE OPERATION  ⚠️            ║${NC}"
    echo -e "${RED}║                                                   ║${NC}"
    echo -e "${RED}║  This will PERMANENTLY DELETE all AWS resources  ║${NC}"
    echo -e "${RED}║  and data. This action CANNOT be undone!         ║${NC}"
    echo -e "${RED}║                                                   ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${YELLOW}To proceed, you must type exactly:${NC} ${RED}destroy everything${NC}"
    echo ""
    read -p "Enter confirmation: " confirmation
    
    if [ "$confirmation" != "destroy everything" ]; then
        print_info "Destruction cancelled. No resources were deleted."
        exit 0
    fi
    
    echo ""
    print_warning "Final confirmation: Are you absolutely sure?"
    read -p "Type 'yes' to continue: " final_confirm
    
    if [ "$final_confirm" != "yes" ]; then
        print_info "Destruction cancelled. No resources were deleted."
        exit 0
    fi
    
    echo ""
}

# Function to empty S3 bucket
empty_s3_bucket() {
    print_header "Emptying S3 Bucket"
    
    cd "$TERRAFORM_DIR"
    
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    if [ -z "$S3_BUCKET" ]; then
        print_warning "S3 bucket name not found, skipping..."
        return 0
    fi
    
    print_info "Emptying S3 bucket: $S3_BUCKET"
    
    # Delete all objects
    if aws s3 rm "s3://$S3_BUCKET" --recursive 2>/dev/null; then
        print_success "S3 bucket emptied"
    else
        print_warning "Could not empty S3 bucket (may already be empty)"
    fi
    
    # Delete all versions if versioning is enabled
    aws s3api delete-objects \
        --bucket "$S3_BUCKET" \
        --delete "$(aws s3api list-object-versions \
            --bucket "$S3_BUCKET" \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --output json 2>/dev/null)" 2>/dev/null || true
    
    echo ""
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_header "Destroying Infrastructure"
    
    cd "$TERRAFORM_DIR"
    
    print_info "Running Terraform destroy..."
    echo ""
    
    if terraform destroy -auto-approve; then
        print_success "All infrastructure destroyed successfully!"
    else
        print_error "Terraform destroy encountered errors"
        print_info "You may need to manually clean up some resources in AWS Console"
        exit 1
    fi
    
    echo ""
}

# Function to clean up local files
cleanup_local_files() {
    print_header "Cleaning Up Local Files"
    
    print_info "Removing generated files..."
    
    # Remove Lambda zip files
    rm -f "$SCRIPT_DIR/lambda/"*.zip
    print_success "Lambda zip files removed"
    
    # Remove deployment info
    rm -f "$SCRIPT_DIR/deployment-info.txt"
    
    # Remove Terraform files (optional)
    read -p "Remove Terraform state files? (y/n): " remove_state
    if [ "$remove_state" = "y" ]; then
        cd "$TERRAFORM_DIR"
        rm -f terraform.tfstate*
        rm -f .terraform.lock.hcl
        rm -rf .terraform/
        print_success "Terraform state files removed"
    else
        print_info "Terraform state files kept for reference"
    fi
    
    echo ""
}

# Function to show completion summary
show_summary() {
    print_header "Destruction Complete"
    
    echo -e "${GREEN}All AWS resources have been destroyed.${NC}\n"
    
    echo -e "${BLUE}What was deleted:${NC}"
    echo -e "  ✓ S3 bucket and all files"
    echo -e "  ✓ CloudFront distribution"
    echo -e "  ✓ Lambda functions"
    echo -e "  ✓ API Gateway"
    echo -e "  ✓ SNS topic and subscriptions"
    echo -e "  ✓ IAM roles and policies"
    echo -e "  ✓ CloudWatch log groups\n"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${BLUE}Backup location:${NC}"
        echo -e "  ${GREEN}$BACKUP_DIR${NC}\n"
    fi
    
    echo -e "${BLUE}To redeploy:${NC}"
    echo -e "  1. Review your backup if needed"
    echo -e "  2. Run: ${YELLOW}./deploy.sh${NC}"
    echo -e "  3. Restore events.json if needed\n"
    
    echo -e "${BLUE}Cost impact:${NC}"
    echo -e "  • No more AWS charges for this project"
    echo -e "  • CloudFront may take up to 24 hours to fully stop billing\n"
}

# Main execution
main() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║     Event Announcement System - DESTROY           ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Check prerequisites
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Execute destruction steps
    check_deployment
    show_resources
    backup_data
    confirm_destruction
    empty_s3_bucket
    destroy_infrastructure
    cleanup_local_files
    show_summary
    
    echo -e "${GREEN}Destruction process completed successfully!${NC}\n"
}

# Run main function
main
