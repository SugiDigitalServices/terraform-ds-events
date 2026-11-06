/**
 * イベントを受け取る口（SQS キュー）を1つ作り、相手のトピックに繋ぐ。
 *
 * キューは **購読側のアカウントに立つ**。publisher の許可リストに自分のアカウントが入っていれば、
 * 申請なしで繋げる。外すのも自分の都合でよい。
 */

locals {
  queue_name = "sugi-ds-${var.consumer}-${var.service}-${var.event}-${var.stage}"
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.queue_name}-dlq"
  message_retention_seconds = var.dlq_retention_seconds
  kms_master_key_id         = var.kms_key_id

  tags = merge(var.tags, {
    Name      = "${local.queue_name}-dlq"
    ManagedBy = "terraform"
  })
}

resource "aws_sqs_queue" "this" {
  name                       = local.queue_name
  message_retention_seconds  = var.retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  kms_master_key_id          = var.kms_key_id

  # 処理に失敗し続けたものは DLQ へ逃がす。逃がさないと、同じメッセージが後続を止め続ける
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, {
    Name      = local.queue_name
    Consumer  = var.consumer
    Service   = var.service
    Event     = var.event
    Stage     = var.stage
    ManagedBy = "terraform"
  })
}

data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "AllowSendFromTopic"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.topic_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue.json
}

resource "aws_sns_topic_subscription" "this" {
  topic_arn = var.topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.this.arn

  # 素のまま受け取る（SNS の封筒を剥がす）。剥がさないと受信側が二重に JSON を解く
  raw_message_delivery = true

  # 属性で絞れるイベントは、要らないものを受け取る前に捨てる
  filter_policy       = var.filter_policy
  filter_policy_scope = var.filter_policy == null ? null : "MessageAttributes"
}

/**
 * DLQ に溜まったら鳴らす。
 *
 * 本体のキューの滞留ではなく DLQ を見るのは、**捨てられたことに気づけないのが一番まずい**ため。
 * 本体の滞留は処理の遅れで、DLQ 行きは取りこぼし。
 */
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  count = var.alarm_sns_topic_arn == null ? 0 : 1

  alarm_name          = "${local.queue_name}-dlq-not-empty"
  alarm_description   = "${local.queue_name} が処理できずに捨てたメッセージがある"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = { QueueName = aws_sqs_queue.dlq.name }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = var.tags
}
