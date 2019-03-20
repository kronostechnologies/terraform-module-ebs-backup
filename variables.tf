variable "lambda_aws_iam_role_name"     { description = "Unique name applied to aws_iam_role of the lambda function. The role name is always prefixed with 'ebs-backup-'." }
variable "lambda_function_name"         { description = "Unique name for the lambda function. The function name is always prefixed with 'ebs-backup-'." }
variable "lambda_cloudwatch_event_name" { description = "Unique name for the cloudwatch event rule ressource. The cloudwatch event name is always prefixed with 'ebs-backup-'." }
variable "lambda_volume_tag_namespace"  { description = "Tag name to look for when filtering ec2 instances. The tag name is always prefixed with 'EbsBackup_TakeSnapshot_'. Use this to namespace your volume." }
variable "lambda_schedule_expression"   { default = "rate(4 hours)" description = "The lambda schedule expression" }
variable "lambda_backup_days_to_keep"   { default = 14 description = "The cleanup lambda will keep that many days' worth of backups."}
variable "lambda_alarm_actions"         { default = [] description = "The list of actions to execute when this alarm transitions into an ALARM state from any other state. Each action is specified as an Amazon Resource Number (ARN)." }
variable "lambda_alarm_period"          { default = 14400 description = "The alarm period in seconds over which the alarm statistic is applied. This value should always be equals or greater than the lambda_schedule_expression" }
