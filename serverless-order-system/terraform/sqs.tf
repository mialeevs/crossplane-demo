# SQS Queue Configuration

resource "aws_sqs_queue" "order_processing_queue" {
  name                       = "${local.name_prefix}-processing-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 86400  # 1 day
  receive_wait_time_seconds  = 10     # Long polling
  visibility_timeout_seconds = 300    # 5 minutes

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-processing-queue"
    }
  )
}

resource "aws_sqs_queue_policy" "order_processing_queue_policy" {
  queue_url = aws_sqs_queue.order_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.order_processing_queue.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.order_processing.arn
        }
      }
    }]
  })
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "order_processing_dlq" {
  name                       = "${local.name_prefix}-processing-dlq"
  message_retention_seconds  = 1209600  # 14 days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-processing-dlq"
    }
  )
}

resource "aws_sqs_queue_redrive_policy" "order_processing_queue_redrive" {
  queue_url = aws_sqs_queue.order_processing_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_processing_dlq.arn
    maxReceiveCount     = 3
  })
}
