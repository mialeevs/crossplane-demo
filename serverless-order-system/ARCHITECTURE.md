# Architecture Documentation

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Client Applications                             │
│                    (Mobile, Web, Postman, etc.)                         │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ HTTPS POST /orders
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS API Gateway (HTTP)                          │
│  - CORS enabled                                                         │
│  - Throttling: 50 req/s burst, 100 req/s steady                         │
│  - CloudWatch logging                                                   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Proxy Integration
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS Lambda (Order Processor)                       │
│  - Runtime: Python 3.12                                                 │
│  - Memory: 256 MB                                                       │
│  - Timeout: 30 seconds                                                  │
│  - Validates input                                                      │
│  - Publishes events                                                     │
└─────────────┬───────────────────────────────────────────────────────────┘
              │
              │ Put Events
              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS EventBridge (Default Bus)                      │
│                                                                         │
│  Event Pattern:                                                         │
│  {                                                                      │
│    "source": ["order.service"],                                         │
│    "detail-type": ["OrderCreated"]                                      │
│  }                                                                      │
└─────────┬─────────────────────────────────────┬─────────────────────────┘
          │                                     │
          │ Rule 1: All Orders                  │ Rule 2: High-Value (≥$1000)
          │                                     │
          ▼                                     ▼
┌─────────────────────────┐         ┌─────────────────────────────────────┐
│      AWS SNS Topic      │         │        AWS SQS Queue                │
│  - Email notifications  │         │  - Max size: 256 KB                 │
│  - Subscribers: Email   │         │  - Retention: 1 day                 │
│  - Delivery retry       │         │  - Long polling: 10s                │
└─────────┬───────────────┘         │  - Visibility timeout: 5 min        │
          │                         │  - DLQ: 3 retries                   │
          │                         └─────────┬───────────────────────────┘
          ▼                                   │
┌─────────────────────────┐                   │ Poll Messages
│   Admin Email Inbox     │                   │
│  - Order notifications  │                   ▼
└─────────────────────────┘         ┌─────────────────────────────────────┐
                                    │    AWS ECS (Fargate) - Worker       │
                                    │  - CPU: 256 (0.25 vCPU)             │
                                    │  - Memory: 512 MB                   │
                                    │  - Container from ECR               │
                                    │  - Processes high-value orders      │
                                    │  - Auto-delete from queue           │
                                    └─────────┬───────────────────────────┘
                                              │
                                              │ Runs in
                                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS VPC (10.0.0.0/16)                              │
│                                                                         │
│  ┌────────────────────────┐  ┌────────────────────────┐                 │
│  │  Private Subnet 1      │  │  Private Subnet 2      │                 │
│  │  10.0.1.0/24           │  │  10.0.2.0/24           │                 │
│  │  - ECS Tasks           │  │  - ECS Tasks           │                 │
│  │  - No public IP        │  │  - No public IP        │                 │
│  └──────────┬─────────────┘  └──────────┬─────────────┘                 │
│             │                           │                               │
│             └─────────┬─────────────────┘                               │
│                       │                                                 │
│  ┌────────────────────┴────────────────────────┐                        │
│  │         NAT Gateways (AZ1, AZ2)             │                        │
│  └────────────────────┬────────────────────────┘                        │
│                       │                                                 │
│  ┌────────────────────┴────────────────────────┐                        │
│  │         Internet Gateway                    │                        │
│  └─────────────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      Supporting Services                                │
│                                                                         │
│  AWS ECR                      AWS CloudWatch                            │
│  - Docker images              - Lambda logs                             │
│  - Image scanning             - API Gateway logs                        │
│  - Lifecycle policies         - ECS logs                                │
│                               - Metrics & alarms                        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. API Gateway (HTTP API)
**Purpose:** HTTP endpoint for order submission

**Features:**
- HTTP API (cheaper and simpler than REST API)
- CORS enabled for web clients
- Request throttling and rate limiting
- CloudWatch logging in JSON format
- Auto-deploy enabled

**Routes:**
- `POST /orders` - Create new order
- `GET /health` - Health check

### 2. Lambda Function
**Purpose:** Process and validate orders

**Responsibilities:**
- Input validation
- Event creation
- EventBridge publishing
- Error handling

**Configuration:**
- Runtime: Python 3.12
- Memory: 256 MB
- Timeout: 30 seconds
- Concurrent executions: Default (1000)

### 3. EventBridge
**Purpose:** Event routing and distribution

**Rules:**
1. **Order Notification Rule**
   - Pattern: All OrderCreated events
   - Target: SNS Topic
   - Purpose: Notify admin of all orders

2. **High-Value Processing Rule**
   - Pattern: OrderCreated with amount >= $1000
   - Target: SQS Queue
   - Purpose: Queue for detailed processing

### 4. SNS Topic
**Purpose:** Real-time notifications

**Features:**
- Email protocol
- Retry logic
- Delivery status logging
- Multiple subscribers support

### 5. SQS Queue
**Purpose:** Durable message queue for high-value orders

**Configuration:**
- Standard queue (not FIFO)
- Message retention: 24 hours
- Visibility timeout: 5 minutes
- Long polling: 10 seconds
- Dead Letter Queue: 3 retries

### 6. ECS/Fargate
**Purpose:** Run containerized workers

**Task Definition:**
- Launch type: Fargate
- CPU: 256 units (0.25 vCPU)
- Memory: 512 MB
- Platform: Linux/x86_64

**Service:**
- Desired count: 1
- Network: Private subnets
- Auto-scaling: Optional

### 7. ECR
**Purpose:** Container registry

**Features:**
- Image scanning on push
- Lifecycle policy (keep last 10)
- Encryption at rest

### 8. VPC
**Purpose:** Network isolation for ECS tasks

**Configuration:**
- CIDR: 10.0.0.0/16
- 2 Availability Zones
- 2 Private subnets (ECS)
- 2 Public subnets (NAT)
- NAT Gateways for outbound
- Internet Gateway

## Data Flow

### Standard Order Flow (< $1000)
```
1. Client → API Gateway
2. API Gateway → Lambda
3. Lambda validates input
4. Lambda → EventBridge (publish event)
5. EventBridge → SNS (all orders rule)
6. SNS → Email notification
7. Lambda → Client (success response)
```

### High-Value Order Flow (≥ $1000)
```
1. Client → API Gateway
2. API Gateway → Lambda
3. Lambda validates input
4. Lambda → EventBridge (publish event)
5. EventBridge → SNS (all orders rule)
6. EventBridge → SQS (high-value rule)
7. SNS → Email notification
8. ECS Worker polls SQS
9. Worker processes order
10. Worker deletes message
11. Lambda → Client (success response)
```

## Security

### Network Security
- ECS tasks in private subnets
- No direct internet access
- NAT Gateways for outbound only
- Security groups with minimal rules

### IAM Security
- Least privilege principles
- Separate roles for each service
- No wildcard permissions
- Resource-specific ARNs

### Data Security
- HTTPS only (API Gateway)
- Encrypted SQS queues
- Encrypted ECR images
- CloudWatch Logs encryption

## Monitoring & Logging

### CloudWatch Logs
- `/aws/lambda/[function-name]` - Lambda logs
- `/aws/apigateway/[api-name]` - API Gateway logs
- `/ecs/[task-name]` - ECS task logs

### Metrics to Monitor
- API Gateway: 4XX, 5XX errors, latency
- Lambda: Invocations, errors, duration, throttles
- SQS: Messages sent, received, queue depth
- ECS: CPU, memory, task count

### Alarms (Recommended)
- High error rate (> 5%)
- Lambda throttling
- SQS queue depth (> 100)
- ECS task failures

## Scalability

### Horizontal Scaling
- Lambda: Automatic (up to 1000 concurrent)
- API Gateway: Automatic
- SQS: Unlimited messages
- ECS: Manual or auto-scaling

### Vertical Scaling
- Lambda: Increase memory (128 MB - 10 GB)
- ECS: Increase CPU/memory

## High Availability

### Built-in HA
- Lambda: Multi-AZ by default
- API Gateway: Multi-AZ by default
- SQS: Distributed across AZs
- EventBridge: Regional service

### Manual HA
- ECS: Deploy across 2 AZs
- NAT Gateways: One per AZ

## Disaster Recovery

### RTO/RPO
- Lambda: Seconds (auto-recovery)
- ECS: Minutes (task restart)
- SQS: No data loss (durable)
- EventBridge: Seconds (managed)

### Backup Strategy
- Terraform state in S3 (recommended)
- ECR images: Lifecycle retention
- CloudWatch Logs: 7-day retention
- SQS DLQ: 14-day retention

## Cost Optimization

### Current Costs (~$17/month)
- ECS Fargate: $15 (largest component)
- Other services: $2

### Optimization Strategies
1. **Scale ECS to zero** when not needed
2. **Use Fargate Spot** (already configured)
3. **Reduce log retention** (currently 7 days)
4. **Use Lambda for workers** instead of ECS
5. **Implement CloudWatch alarms** for cost tracking

## Performance

### Latency Targets
- API Gateway → Lambda: < 100ms
- Lambda execution: < 500ms
- EventBridge delivery: < 1s
- SNS delivery: < 5s
- SQS polling: < 30s

### Throughput
- API Gateway: 10,000 req/s (default)
- Lambda: 1000 concurrent (default)
- SQS: Unlimited
- EventBridge: 10,000 events/s

## Future Enhancements

1. **Authentication**
   - API Gateway Cognito authorizer
   - API keys for external clients

2. **Auto-Scaling**
   - ECS target tracking
   - Based on SQS queue depth

3. **Observability**
   - AWS X-Ray tracing
   - Custom CloudWatch metrics
   - Structured logging

4. **Reliability**
   - Circuit breakers
   - Retry with exponential backoff
   - DLQ processing

5. **CI/CD**
   - GitHub Actions
   - Automated testing
   - Blue-green deployments
