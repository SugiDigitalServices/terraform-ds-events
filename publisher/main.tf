/**
 * イベントを公開する口（SNS トピック）を1つ作る。
 *
 * トピックは **publisher のアカウントに立つ**。購読する側は、ここで許したアカウントから
 * 自分のキューを繋ぐ（申請は要らない）。
 */

locals {
  # 購読側が ARN を組み立てられるように、名前は完全に固定する（publisher は選べない）
  topic_name = "sugi-ds-${var.service}-${var.event}-${var.stage}"
}

resource "aws_sns_topic" "this" {
  name              = local.topic_name
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Name      = local.topic_name
    Service   = var.service
    Event     = var.event
    Stage     = var.stage
    ManagedBy = "terraform"
  })
}

data "aws_iam_policy_document" "topic" {
  # publisher 自身が流す
  statement {
    sid       = "AllowPublishFromOwner"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }

  # 購読を許すアカウント。ここに入っていれば、購読側は自分の都合で繋いだり外したりできる
  dynamic "statement" {
    for_each = length(var.subscriber_account_ids) > 0 ? [1] : []

    content {
      sid       = "AllowSubscribeFromListedAccounts"
      actions   = ["sns:Subscribe", "sns:GetTopicAttributes"]
      resources = [aws_sns_topic.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.subscriber_account_ids
      }
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic.json
}

/**
 * 配信に失敗した件数で鳴らす。
 *
 * 閾値を 0 にしているのは、イベントの配信失敗が常態化してよい理由が無いため。
 * 鳴ったら購読側のキューか権限が壊れている（publisher 側の障害ではないことが多い）。
 */
resource "aws_cloudwatch_metric_alarm" "delivery_failed" {
  count = var.alarm_sns_topic_arn == null ? 0 : 1

  alarm_name          = "${local.topic_name}-delivery-failed"
  alarm_description   = "${local.topic_name} の配信が失敗した。購読側のキューか権限を見る"
  namespace           = "AWS/SNS"
  metric_name         = "NumberOfNotificationsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = { TopicName = aws_sns_topic.this.name }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = var.tags
}
