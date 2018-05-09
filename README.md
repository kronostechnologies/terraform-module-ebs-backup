# terraform-module-ebs-backup
AWS Terraform module to take a periodic snapshot based of ec2 volume based on tags

## Usage
The example below will create a lambda that will create a snapshot every 4 hours of
all volume for which a tag named `EbsBackup_TakeSnapshot_Prod` exist and that it's
 value is either `yes`, `true`, `1` or `y`.

```
module "ebs_backup" {
  source = "github.com/kronostechnologies/terraform-module-ebs-backup?ref=1.0.0"
  lambda_aws_iam_role_name = "create-snapshot"
  lambda_function_name = "lambda"
  lambda_cloudwatch_event_name = "rule"
  lambda_schedule_expression = "rate(4 hours)"
  lambda_volume_tag_namespace = "Prod"
}
```

  > It is extremely important to not use the same `lambda_*` values for different environment in the same aws account. If you do, the two module will destroy and recreate each other's ressources.


## Variables
See `variables.tf` file

## Snapshot Tag Output
Below are the tags added to a snapshot

### EbsBackup_InstanceId
Instance id from which the volume is attached

### EbsBackup_InstanceName
Instance name from which the volume is attached

### EbsBackup_VolumeName
Name of the volume

### EbsBackup_DeviceName
Device name of the volume

### EbsBackup_DatetimeUTC
UTC Date of when the snapshot started

### EbsBackup_Timestamp
Unix timestamp of when the snapshot started

### EbsBackup_LambdaARN
The Lambda ARN that this snapshot was generated from

### EbsBackup_LambdaFunctionName
The lambda function name that took this snapshot

### EbsBackup_LambdaFunctionVersion
The lambda function version that took this snapshot
