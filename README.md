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
