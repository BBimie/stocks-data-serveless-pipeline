# Serveless Stocks Market Data Pipeline

Extracts stocks market data of 3 days ago (free tier, to ensure success) everyday at 2 am GMT+1 (1am UTC).

# IAC
I needed the following resources

1. IAM Role
2. IAM Policy
3. aws_iam_role_policy_attachment
4. S3 Bucket
5. archive_file
6. aws_lambda_function
7. Layer - aws_lambda_layer_version
8. Link layer - function
9. Eventbridge scheduler
10. Invoke scheduler privilege


## SETUP Terraform Access to AWS
- Install AWS CLI https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Configure AWS `aws configure`
- Terraform zips the lambda function script and the massiv-python-client layer and uploads



Pipeline:

- Extraction:
    - Idempotency; used the date of the api data being fetched as the file name
    - Get's the stocks data for 3 days ago (i am on the free api, to ensure I always get data) (skips weekends)
    - Scheduling: AWS Eventbridge triggers everyday by 2am gmt+1 which is 1am utc
    - Manually added the polygon-api-key to aws secrets on the console, and had a function in the lambda function code to get the secret



## HOW TO RUN
- You can modify the Tickers you want to extract their stocks market data, this project is really simple and focuses on just 
`["MSFT", "GOOGL", "AMZN", "TSLA", "NVDA", "INTC", "ADBE", "NFLX", "PYPL"]`

1. Get massive (polygon) free api key
2. SETUP Terraform Access to AWS
    - Install AWS CLI https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    - Configure AWS `aws configure` and pass in the correct values when prompted

3. CD to the terraform dir and run `terraform init`
4. Run `terraform plan`
5. `terraform apply`
6. Manually update the api_key secret on the console 
