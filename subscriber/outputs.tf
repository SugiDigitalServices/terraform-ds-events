output "queue_arn" {
  description = "受け取ったイベントを処理する Lambda / ECS に渡す"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  value = aws_sqs_queue.this.id
}

output "dlq_arn" {
  description = "捨てられたメッセージの置き場。中身を見るときに使う"
  value       = aws_sqs_queue.dlq.arn
}
