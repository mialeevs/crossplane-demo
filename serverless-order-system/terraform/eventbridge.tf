# EventBridge Configuration

# Rule 1: Send all orders to SNS for notifications
resource "aws_cloudwatch_event_rule" "order_notification" {
  name        = "${local.name_prefix}-order-notification"
  description = "Send SNS notification on order creation"
  
  event_pattern = jsonencode({
    source      = ["order.service"]
    detail-type = ["OrderCreated"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-notification-rule"
    }
  )
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.order_notification.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.order_notifications.arn
}

# Rule 2: Send high-value orders to SQS for processing
resource "aws_cloudwatch_event_rule" "order_processing" {
  name        = "${local.name_prefix}-order-processing"
  description = "Queue high-value orders for detailed processing"
  
  event_pattern = jsonencode({
    source      = ["order.service"]
    detail-type = ["OrderCreated"]
    detail = {
      amount = [{
        numeric = [">=", var.high_value_threshold]
      }]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-processing-rule"
    }
  )
}

resource "aws_cloudwatch_event_target" "sqs_target" {
  rule      = aws_cloudwatch_event_rule.order_processing.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.order_processing_queue.arn
}
