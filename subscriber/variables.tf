variable "topic_arn" {
  description = "繋ぎ先のトピック。名前は規約で固定なので、publisher に聞かずに組み立ててよい"
  type        = string
}

variable "consumer" {
  description = "受け取る側のサービス（例: sugi-coupon）"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.consumer))
    error_message = "consumer は英小文字・数字・ハイフンのみ。"
  }
}

variable "service" {
  description = "イベントを出している側のサービス（例: sugi-account）"
  type        = string
}

variable "event" {
  description = "イベント名（例: member-withdrawn）"
  type        = string
}

variable "stage" {
  description = "環境"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.stage)
    error_message = "stage は dev / stg / prod のいずれか。"
  }
}

variable "retention_seconds" {
  description = "本体のキューの保持期間。既定は 4 日（連休で受信側が止まっても溶けない長さ）"
  type        = number
  default     = 345600
}

variable "dlq_retention_seconds" {
  description = "DLQ の保持期間。既定は上限の 14 日（捨てたものを調べる時間を長く取る）"
  type        = number
  default     = 1209600
}

variable "visibility_timeout_seconds" {
  description = "処理中に他のワーカーへ見えなくする時間。受信側の処理時間の 6 倍が目安"
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "この回数だけ失敗したら DLQ へ逃がす"
  type        = number
  default     = 5
}

variable "filter_policy" {
  description = "要らないイベントを受け取る前に捨てる条件（JSON 文字列）。null なら全部受け取る"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "キューの暗号化に使う KMS キー。null なら暗号化しない"
  type        = string
  default     = null
}

variable "alarm_sns_topic_arn" {
  description = "DLQ に溜まったことを知らせる先。null ならアラームを作らない"
  type        = string
  default     = null
}

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
}
