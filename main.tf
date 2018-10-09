##
# LAMBDA PERMISSION
##
resource "aws_iam_role" "lambda" {
  name               = "ebs-backup-${var.lambda_aws_iam_role_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda" {
  name = "ebs-backup-${var.lambda_aws_iam_role_name}"
  role = "${aws_iam_role.lambda.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "logs:*"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:ModifySnapshotAttribute",
        "ec2:ResetSnapshotAttribute",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

##
# LAMBDA FILE
##

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "lambda" {
  runtime          = "python2.7"
  filename         = "${path.module}/lambda.zip"
  function_name    = "ebs-backup-${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "lambda.lambda_handler"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  timeout          = 3
  environment {
    variables = {
      LAMBDA_VOLUME_TAG_NAMESPACE= "EbsBackup_TakeSnapshot_${var.lambda_volume_tag_namespace}"
    }
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lambda.arn}"
}

resource "aws_cloudwatch_event_rule" "lambda" {
  name                = "ebs-backup-${var.lambda_cloudwatch_event_name}"
  schedule_expression = "${var.lambda_schedule_expression}"
}

resource "aws_cloudwatch_event_target" "lambda" {
  target_id = "ebs-backup-${var.lambda_cloudwatch_event_name}"
  rule      = "${aws_cloudwatch_event_rule.lambda.name}"
  arn       = "${aws_lambda_function.lambda.arn}"
}

##
# LAMBDA FILE - CLEANUP
##

data "archive_file" "lambda-cleanup" {
  type        = "zip"
  source_file = "${path.module}/lambda-cleanup.py"
  output_path = "${path.module}/lambda-cleanup.zip"
}

resource "aws_lambda_function" "lambda-cleanup" {
  runtime          = "python2.7"
  filename         = "${path.module}/lambda-cleanup.zip"
  function_name    = "ebs-backup-cleanup-${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "lambda-cleanup.lambda_handler"
  source_code_hash = "${data.archive_file.lambda-cleanup.output_base64sha256}"
  timeout          = 3
  environment {
    variables = {
      LAMBDA_VOLUME_TAG_NAMESPACE= "EbsBackup_TakeSnapshot_${var.lambda_volume_tag_namespace}",
      LAMBDA_BACKUP_DAYS_TO_KEEP="${var.lambda_backup_days_to_keep}"
    }
  }
}

resource "aws_lambda_permission" "cloudwatch-cleanup" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda-cleanup.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lambda-cleanup.arn}"
}

resource "aws_cloudwatch_event_rule" "lambda-cleanup" {
  name                = "ebs-backup-cleanup-${var.lambda_cloudwatch_event_name}"
  schedule_expression = "${var.lambda_schedule_expression}"
}

resource "aws_cloudwatch_event_target" "lambda-cleanup" {
  target_id = "ebs-backup-cleanup-${var.lambda_cloudwatch_event_name}"
  rule      = "${aws_cloudwatch_event_rule.lambda-cleanup.name}"
  arn       = "${aws_lambda_function.lambda-cleanup.arn}"
}
