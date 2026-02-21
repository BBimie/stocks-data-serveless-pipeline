# 1. IAM Role for Lambda
resource "aws_iam_role" "stocks_lambda_role" {
  name = "stocks_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = ["lambda.amazonaws.com", 
                              "scheduler.amazonaws.com"] 
                  }
    }]
  })
}

# 2. IAM Policy (S3, CloudWatch, SSM)
resource "aws_iam_policy" "stocks_lambda_policy" {
  name        = "stocks_lambda_policy"
  description = "Permissions for stocks lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.stocks_lake.arn}/*"
      },
      {
        Action   = "secretsmanager:GetSecretValue"
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.polygon_api_key.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

#attach role & policy
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.stocks_lambda_role.name
  policy_arn = aws_iam_policy.stocks_lambda_policy.arn
}

# 3. S3 Bucket
resource "aws_s3_bucket" "stocks_lake" {
  bucket = "massive-stocks-lake-2026"
}

# 4. Secrets Manager
resource "aws_secretsmanager_secret" "polygon_api_key" {
  name        = "polygon_api_key_secret"
  description = "Polygon API Key (Updated manually in Console)"

  lifecycle {
    ignore_changes = all
  }
}

# 5. Layer Dependencies
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.module}/layers/python
      pip3 install massive -t ${path.module}/layers/python
    EOT
  }

  triggers = {
    build_number = "1.0"
  }
}

# 6. Archive the Layer
data "archive_file" "massive_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layers"
  output_path = "${path.module}/massive_layer.zip"

  depends_on = [null_resource.install_dependencies]
}

resource "aws_lambda_layer_version" "massive_layer" {
  filename            = data.archive_file.massive_layer_zip.output_path
  source_code_hash    = data.archive_file.massive_layer_zip.output_base64sha256
  layer_name          = "massive_api_layer"
  compatible_runtimes = ["python3.11"]
}

# 7. Archive the Lambda Code
data "archive_file" "stocks_lambda_archive" {
  type        = "zip"
  source_file = "${path.module}/../get_stocks_data.py" 
  output_path = "${path.module}/get_stocks_data.zip"
}

# 8. The Lambda Function
resource "aws_lambda_function" "stocks_lambda_function" {
  filename         = data.archive_file.stocks_lambda_archive.output_path
  source_code_hash = data.archive_file.stocks_lambda_archive.output_base64sha256
  
  function_name    = "stocks-lambda-ingestor"
  role             = aws_iam_role.stocks_lambda_role.arn
  
  # Handler format: [filename].[function_name]
  handler          = "get_stocks_data.lambda_handler" 
  runtime          = "python3.11"
  timeout          = 300 

  layers = [aws_lambda_layer_version.massive_layer.arn,
            "arn:aws:lambda:eu-north-1:336392948345:layer:AWSSDKPandas-Python311:25"]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.stocks_lake.id
      SECRET_NAME = aws_secretsmanager_secret.polygon_api_key.name
    }
  }
}

#9. Allow scheduler to trigger lambda function
resource "aws_iam_policy" "scheduler_invoke_policy" {
  name = "scheduler_invoke_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = aws_lambda_function.stocks_lambda_function.arn
    }]
  })
}


resource "aws_iam_role_policy_attachment" "scheduler_attach" {
  role       = aws_iam_role.stocks_lambda_role.name
  policy_arn = aws_iam_policy.scheduler_invoke_policy.arn
}

# 10. Event bridge scheduler
resource "aws_scheduler_schedule" "stocks-lambda-scheduler" {
  name       = "stocks-lambda-scheduler"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }
  end_date = "2026-03-02T23:59:59Z"
  action_after_completion = "DELETE"

  schedule_expression = "cron(0 1 * * ? *)"

  target {
    arn      = aws_lambda_function.stocks_lambda_function.arn
    role_arn = aws_iam_role.stocks_lambda_role.arn
  }
}

# 11. S3 BUcket for my terraform state
resource "aws_s3_bucket" "massive-stocks-api-tfstate" {
  bucket = "massive-stocks-api-tfstate" 
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "massive-stocks-state_versioning" {
  bucket = aws_s3_bucket.massive-stocks-api-tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}