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
  role = aws_iam_role.lambda.id
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
  runtime          = "python3.12"
  filename         = "${path.module}/lambda.zip"
  function_name    = "ebs-backup-${var.lambda_function_name}"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 3
  environment {
    variables = {
      LAMBDA_VOLUME_TAG_NAMESPACE = "EbsBackup_TakeSnapshot_${var.lambda_volume_tag_namespace}"
    }
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda.arn
}

resource "aws_cloudwatch_event_rule" "lambda" {
  name                = "ebs-backup-${var.lambda_cloudwatch_event_name}"
  schedule_expression = var.lambda_schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  target_id = "ebs-backup-${var.lambda_cloudwatch_event_name}"
  rule      = aws_cloudwatch_event_rule.lambda.name
  arn       = aws_lambda_function.lambda.arn
}

resource "aws_cloudwatch_metric_alarm" "lambda-ebs-backup-error" {
  alarm_name          = "${aws_lambda_function.lambda.function_name}-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.lambda_alarm_period
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors error with lambda function '${aws_lambda_function.lambda.function_name}'"
  alarm_actions       = var.lambda_alarm_actions
  dimensions = {
    FunctionName = aws_lambda_function.lambda.function_name
  }
}
