#!/bin/bash

set -e

echo "========================================="
echo "Serverless Order System Deployment"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found${NC}"
    echo "Creating terraform.tfvars from example..."
    
    cat > terraform.tfvars << EOF
aws_region   = "us-east-1"
project_name = "serverless-order-system"
environment  = "dev"
admin_email  = "your-email@example.com"  # Change this!
high_value_threshold = 1000
EOF
    
    echo -e "${YELLOW}Please edit terraform/terraform.tfvars with your email address${NC}"
    echo -e "${YELLOW}Then run this script again.${NC}"
    exit 1
fi

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan
echo -e "${BLUE}Creating Terraform plan...${NC}"
terraform plan -out=tfplan
echo ""

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply tfplan
rm tfplan
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Get outputs
echo -e "${BLUE}Getting deployment outputs...${NC}"
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}📡 API Endpoint:${NC}"
echo "   $API_URL"
echo ""
echo -e "${BLUE}📧 Next Steps:${NC}"
echo "   1. Check your email and confirm SNS subscription"
echo "   2. Build and push Docker image:"
echo "      cd .."
echo "      ./scripts/build-and-push-docker.sh"
echo ""
echo -e "${BLUE}🧪 Test the API:${NC}"
echo "   curl -X POST $API_URL \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"order_id\": \"ORD-001\", \"customer_id\": \"CUST-123\", \"amount\": 1500}'"
echo ""
echo -e "${BLUE}📊 Monitor logs:${NC}"
echo "   Lambda: aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow"
echo "   ECS:    aws logs tail /ecs/serverless-order-system-order-worker-dev --follow"
echo ""

# Save outputs to file
cat > ../deployment-info.txt << EOF
Deployment Information
======================
Date: $(date)
API URL: $API_URL
ECR Repository: $ECR_URL
ECS Cluster: $CLUSTER_NAME
ECS Service: $SERVICE_NAME

Test Command:
curl -X POST $API_URL \\
  -H "Content-Type: application/json" \\
  -d '{"order_id": "ORD-001", "customer_id": "CUST-123", "amount": 1500}'
EOF

echo -e "${GREEN}Deployment information saved to deployment-info.txt${NC}"
