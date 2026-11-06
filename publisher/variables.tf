variable "service" {
  description = "イベントを出すサービス（catalog の repo 名に合わせる。例: sugi-account）"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.service))
    error_message = "service は英小文字・数字・ハイフンのみ。"
  }
}

variable "event" {
  description = "イベント名。過去形の事実で書く（例: member-withdrawn）。「何をすべきか」は入れない"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.event))
    error_message = "event は英小文字・数字・ハイフンのみ。"
  }
}

variable "stage" {
  description = "環境"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.stage)
    error_message = "stage は dev / stg / prod のいずれか。"
  }
}

variable "subscriber_account_ids" {
  description = <<-EOT
    購読を許す AWS アカウント ID。ここに入っていれば、購読側は申請なしで繋いだり外したりできる。
    **誰が何を購読しているかの台帳は持たない**（持つと必ず腐り、持ち主が律速になる）。
  EOT
  type        = list(string)
  default     = []
}

variable "kms_key_id" {
  description = "トピックの暗号化に使う KMS キー。null なら暗号化しない（個人情報を載せるなら必ず指定する）"
  type        = string
  default     = null
}

variable "alarm_sns_topic_arn" {
  description = "配信失敗を知らせる先。null ならアラームを作らない"
  type        = string
  default     = null
}

variable "tags" {
  description = "追加のタグ"
  type        = map(string)
  default     = {}
}
