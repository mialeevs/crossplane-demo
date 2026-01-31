# SNS Topic and Subscription Configuration

resource "aws_sns_topic" "order_notifications" {
  name              = "${local.name_prefix}-order-notifications"
  display_name      = "Order Notifications - ${var.environment}"
  fifo_topic        = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-notifications"
    }
  )
}

resource "aws_sns_topic_policy" "order_notifications_policy" {
  arn = aws_sns_topic.order_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.order_notifications.arn
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.order_notifications.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "email"
  endpoint  = var.admin_email
}
