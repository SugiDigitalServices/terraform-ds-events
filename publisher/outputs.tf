output "topic_arn" {
  description = "購読側に渡す ARN。名前が固定なので、購読側は publisher に聞かずに組み立ててもよい"
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  value = aws_sns_topic.this.name
}
