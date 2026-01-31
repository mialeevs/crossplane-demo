# Serverless Order Processing System

A complete serverless architecture on AWS demonstrating Lambda, API Gateway, EventBridge, SNS, SQS, ECS, and ECR working together.

## Architecture Overview

```
Client → API Gateway → Lambda → EventBridge → SNS (Email Notifications)
                                           → SQS → ECS/Fargate Workers
```

## Features

- ✅ RESTful API with API Gateway
- ✅ Serverless compute with Lambda
- ✅ Event-driven architecture with EventBridge
- ✅ Real-time notifications via SNS
- ✅ Asynchronous processing with SQS
- ✅ Containerized workers with ECS/Fargate
- ✅ Container registry with ECR
- ✅ Complete Infrastructure as Code with Terraform
- ✅ Ready-to-test with Postman/REST Client

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Docker installed
- Python 3.12+
- An AWS account with appropriate permissions

## Project Structure

```
serverless-order-system/
├── README.md
├── terraform/           # Infrastructure as Code
│   ├── main.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── api_gateway.tf
│   ├── lambda.tf
│   ├── eventbridge.tf
│   ├── sns.tf
│   ├── sqs.tf
│   ├── ecr.tf
│   ├── ecs.tf
│   ├── vpc.tf
│   ├── iam_lambda.tf
│   └── iam_ecs.tf
├── lambda/              # Lambda function code
│   └── lambda_function.py
├── docker/              # ECS worker container
│   ├── Dockerfile
│   ├── worker.py
│   └── requirements.txt
├── scripts/             # Deployment and utility scripts
│   ├── deploy.sh
│   ├── build-and-push-docker.sh
│   └── destroy.sh
└── tests/               # API test files
    └── api-tests.http

```

## Quick Start

### 1. Clone and Configure

```bash
cd serverless-order-system/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:
```hcl
aws_region   = "us-east-1"
project_name = "my-order-system"
environment  = "dev"
admin_email  = "your-email@example.com"
```

### 2. Deploy Infrastructure

```bash
# From project root
chmod +x scripts/*.sh
./scripts/deploy.sh
```

This will:
- Initialize Terraform
- Create all AWS resources
- Build and push Docker image to ECR
- Deploy ECS service
- Output your API endpoint

### 3. Test the API

After deployment, you'll get an API endpoint like:
```
https://abc123xyz.execute-api.us-east-1.amazonaws.com
```

**Option 1: Using cURL**
```bash
curl -X POST https://YOUR-API-ENDPOINT/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-12345",
    "customer_id": "CUST-789",
    "amount": 1500
  }'
```

**Option 2: Using VSCode REST Client**
Open `tests/api-tests.http` and update the `@baseUrl` variable with your API endpoint, then click "Send Request".

**Option 3: Using Postman**
Import the collection or manually create a POST request to `/orders` endpoint.

### 4. Verify the Flow

1. **Check Lambda Logs:**
   ```bash
   aws logs tail /aws/lambda/YOUR-FUNCTION-NAME --follow
   ```

2. **Check EventBridge:**
   Events are automatically published when orders are created.

3. **Check SNS:**
   You'll receive an email notification (confirm subscription first).

4. **Check SQS:**
   ```bash
   aws sqs receive-message --queue-url YOUR-QUEUE-URL
   ```

5. **Check ECS Logs:**
   ```bash
   aws logs tail /ecs/YOUR-LOG-GROUP-NAME --follow
   ```

## How It Works

### Flow Explanation

1. **API Request:** Client sends POST request to `/orders` endpoint
2. **Lambda Processing:** API Gateway triggers Lambda function
3. **Event Publishing:** Lambda publishes event to EventBridge
4. **Event Routing:** EventBridge routes events based on rules:
   - All orders → SNS (email notification)
   - High-value orders (≥$1000) → SQS queue
5. **Worker Processing:** ECS tasks poll SQS and process messages
6. **Cleanup:** Worker deletes message from queue after processing

### Order Processing Logic

**Low-value orders (< $1000):**
- SNS notification only
- Immediate processing

**High-value orders (≥ $1000):**
- SNS notification
- Queued in SQS for detailed processing
- Processed by ECS worker with 5-second simulation

## Testing Different Scenarios

### Test 1: Low-Value Order (No Queue)
```json
{
  "order_id": "ORD-001",
  "customer_id": "CUST-123",
  "amount": 500
}
```
Expected: SNS notification only

### Test 2: High-Value Order (Queued)
```json
{
  "order_id": "ORD-002",
  "customer_id": "CUST-456",
  "amount": 2500
}
```
Expected: SNS notification + SQS message + ECS processing

## Monitoring

### CloudWatch Dashboards

View logs in CloudWatch:
```bash
# Lambda logs
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow

# API Gateway logs
aws logs tail /aws/apigateway/serverless-order-system-dev --follow

# ECS logs
aws logs tail /ecs/serverless-order-system-order-worker-dev --follow
```

### Metrics to Monitor

- API Gateway: Request count, latency, 4xx/5xx errors
- Lambda: Invocations, duration, errors
- SQS: Messages sent, messages received, queue depth
- ECS: CPU utilization, memory utilization, task count

## Cost Estimates

Approximate monthly costs for moderate usage (assuming 10,000 requests/month):

- **API Gateway:** ~$0.35
- **Lambda:** ~$0.20 (with free tier)
- **EventBridge:** ~$0.10
- **SNS:** ~$0.50
- **SQS:** ~$0.40
- **ECS Fargate:** ~$15 (1 task, 24/7)
- **ECR:** ~$0.10
- **CloudWatch Logs:** ~$0.50

**Total:** ~$17/month

💡 **Tip:** Scale ECS to 0 tasks when not in use to save ~$15/month

## Customization

### Change AWS Region
Edit `terraform/terraform.tfvars`:
```hcl
aws_region = "eu-west-1"
```

### Modify High-Value Threshold
Edit `terraform/eventbridge.tf`, line with `numeric = [">=", 1000]`

### Adjust ECS Resources
Edit `terraform/ecs.tf`:
```hcl
cpu    = "512"   # 0.25, 0.5, 1, 2, 4 vCPU
memory = "1024"  # 512, 1024, 2048, etc. MB
```

### Scale ECS Workers
```bash
aws ecs update-service \
  --cluster YOUR-CLUSTER \
  --service YOUR-SERVICE \
  --desired-count 3
```

## Troubleshooting

### Issue: Lambda timeout
**Solution:** Increase timeout in `terraform/lambda.tf`:
```hcl
timeout = 60  # seconds
```

### Issue: ECS task fails to start
**Solution:** Check ECR image exists:
```bash
aws ecr describe-images --repository-name YOUR-REPO
```

### Issue: No SNS notifications
**Solution:** Confirm SNS subscription:
```bash
aws sns list-subscriptions
```
Check your email and confirm subscription.

### Issue: SQS messages not processing
**Solution:** Check ECS service is running:
```bash
aws ecs describe-services --cluster YOUR-CLUSTER --services YOUR-SERVICE
```

## Cleanup

**Destroy all resources:**
```bash
./scripts/destroy.sh
```

Or manually:
```bash
cd terraform
terraform destroy
```

⚠️ **Warning:** This will delete all resources and data!

## Security Best Practices

- ✅ Least privilege IAM roles
- ✅ VPC with private subnets for ECS
- ✅ Encrypted SQS queues (default)
- ✅ ECR image scanning enabled
- ✅ CloudWatch logging enabled
- ✅ API Gateway CORS configured

## Production Readiness Checklist

- [ ] Enable API Gateway throttling
- [ ] Add API Gateway authentication (API Key/Cognito)
- [ ] Enable AWS WAF for API Gateway
- [ ] Add DLQ (Dead Letter Queue) for Lambda
- [ ] Enable ECS auto-scaling
- [ ] Set up CloudWatch alarms
- [ ] Enable X-Ray tracing
- [ ] Add backup strategy for stateful data
- [ ] Implement CI/CD pipeline
- [ ] Add secrets management (AWS Secrets Manager)

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use this project for learning and production.

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review Terraform state
3. Verify IAM permissions
4. Check AWS service quotas

---

**Built with ❤️ using AWS Serverless Technologies**
