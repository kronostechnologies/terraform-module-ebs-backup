output "aws_iam_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.lambda.function_name
}

