# terraform-ds-events

サービス間のイベント連携（pub/sub）を、**どのサービスでも同じ形**で作るための Terraform module。

## 所有の線

**キューは publisher が持つ。この repo はコードを配るだけで、動いているものを1つも持たない。**

| | 置き場 | 触る人 |
|---|---|---|
| module のコード | この repo | 共通基盤 |
| module を呼ぶ数行 | 各サービスの cloudinfra | そのサービス |
| できたトピック・キュー | **そのサービスの AWS アカウント** | そのサービス（障害対応も費用も） |

中央がキューを持つと、他人のイベントの可用性に中央が責任を負う。イベントが詰まったとき、原因が
publisher のバグでも中央が切り分けることになる。**運用作業が中央に集まる形は採らない。**

**購読に申請は要らない。** publisher が許可リストにアカウントを入れていれば、購読側は自分の都合で
繋いだり外したりできる。**誰が何を購読しているかの台帳は持たない**——持つと必ず腐り、
持ち主が律速になる。

## 使い方

### 出す側

```hcl
module "member_withdrawn" {
  source = "git::https://github.com/<org>/terraform-ds-events.git//publisher?ref=v1.0.0"

  service = "sugi-account"
  event   = "member-withdrawn"
  stage   = var.stage

  subscriber_account_ids = ["111111111111", "222222222222"]
  alarm_sns_topic_arn    = aws_sns_topic.alerts.arn
  kms_key_id             = aws_kms_key.events.id
}
```

これだけで、トピック・許可の口・配信失敗のアラーム・タグが揃う。**名前は選べない**（下記）。

### 受け取る側

```hcl
module "on_member_withdrawn" {
  source = "git::https://github.com/<org>/terraform-ds-events.git//subscriber?ref=v1.0.0"

  topic_arn = "arn:aws:sns:ap-northeast-1:333333333333:sugi-ds-sugi-account-member-withdrawn-prod"
  consumer  = "sugi-coupon"
  service   = "sugi-account"
  event     = "member-withdrawn"
  stage     = var.stage

  alarm_sns_topic_arn = aws_sns_topic.alerts.arn
}
```

キュー・DLQ・再試行・受信の権限・DLQ のアラームが揃う。`queue_arn` を Lambda や ECS に渡す。

## 名前は規約で固定する

```
トピック: sugi-ds-{service}-{event}-{stage}
キュー  : sugi-ds-{consumer}-{service}-{event}-{stage}
```

**publisher は名前を選べない。** 固定しているのは、購読側が ARN を自分で組み立てられるようにするため
（publisher に聞く往復が消える）。

`event` は **過去形の事実**で書く（`member-withdrawn`）。「何をすべきか」を名前に入れない
（`cancel-subscription` のような命令形は、受け取る側の判断を publisher が決めてしまう）。

## 中身は「事実と区分」にする。結論を載せない

```json
{
  "eventId": "01JBX...",
  "occurredAt": "2026-11-05T09:12:34.567Z",
  "version": 1,
  "commonId": "CID000123456",
  "reason": "user_request",
  "channel": "portal"
}
```

**「だから何をすべきか」は受け取る側が決める。** 基盤が「このサービスも解約すべき」のような結論を
載せると、判断ロジックが基盤と消費側の2箇所に散る。基盤が持つのは素材だけ。

`eventId` を必ず入れる。**同じイベントが2回届く前提**で受け取る側を作る（SQS は少なくとも1回）。

## 形を変えるときは

**イベントのメッセージ構造は、破壊的変更をしてはいけない面に入っている。** 正典は
`org-spec/decisions/change-safety.md`。判定はこれ1つ——**どちらを先にデプロイしても壊れないか**。

足すのは自由（受け取る側は知らない項目を無視する）。消す・意味を変える・必須にするのは破壊的変更。
変えたいときは `version` を上げた新しいイベントを別名で出し、古い方を残す。

## module の版

`ref=v1.0.0` で止める。**この repo を直しても、利用側が版を上げるまで何も起きない。**
中央が各サービスのデプロイを壊せない形にしてある。

セキュリティの修正など、上げてほしい版があるときだけ連絡する。それが共通基盤側の唯一の仕事。

## なぜ SNS か

| | SNS → SQS | EventBridge |
|---|---|---|
| 多数の購読者へ配る | 素直。購読側が自分のキューを持つ | できるが、バスの所有者が1つになりやすい |
| 所有を publisher に置く | トピックが publisher のもの、で自然 | バスを publisher ごとに作るのは設計思想とずれる |
| 取りこぼしの再送 | 購読側の SQS に最大14日残る | アーカイブとリプレイが強い |
| ルーティング | 属性フィルタ | ルールで柔軟 |

**所有を publisher に置くことを優先**して SNS を採った。クーポン（coupon-admin ↔ coupon-api）が
EventBridge を使っているのは「直接依存の回避」が目的で、多数配信の文脈ではない。

取りこぼしのリプレイが要るイベントが出てきたら、そのときに EventBridge 版の module を足す
（この repo に並べる。利用側は `source` の末尾を変えるだけ）。
