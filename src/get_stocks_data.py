
from datetime import datetime, timedelta
import os
import time
from io import StringIO
import csv
import boto3
import pandas as pd
from massive import RESTClient
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


CACHED_API_KEY = None

def get_secret():
    global CACHED_API_KEY
    if CACHED_API_KEY:
        return CACHED_API_KEY
    
    secret_name = os.environ.get("SECRET_NAME", "polygon_api_key_secret")
    region_name = "eu-north-1" 

    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=region_name)

    try:
        response = client.get_secret_value(SecretId=secret_name)
        CACHED_API_KEY = response['SecretString']
        return CACHED_API_KEY
    except ClientError as e:
        logging.info(f"Error retrieving secret: {e}")
        raise e

def lambda_handler(event, context):
    api_key = get_secret()
    bucket_name = os.environ.get("BUCKET_NAME")
    
    # get data from 3days ago if it is not a weekend
    target_date = datetime.now() - timedelta(days=3)
    date_str = target_date.strftime('%Y-%m-%d')
    
    # Business Day Check
    if len(pd.bdate_range(date_str, date_str)) == 0:
        logging.info(f"Date {date_str} is a weekend. Skipping.")
        return {'statusCode': 200, 'body': f"Skipped weekend: {date_str}"}

    # API Setup
    tickers = ["MSFT", "GOOGL", "AMZN", "TSLA", "NVDA", "INTC", "ADBE", "NFLX", "PYPL"]
    client = RESTClient(api_key)
    s3_client = boto3.client('s3')

    for ticker in tickers:
        logging.info(f"Processing {ticker} for {date_str}...")
        ticker_aggs = []
        
        try:
            for a in client.list_aggs(
                ticker=ticker,
                multiplier=1,
                timespan="minute",
                from_=date_str,
                to=date_str,
                limit=5000
            ):
                ticker_aggs.append(a)
            
            if not ticker_aggs:
                continue

            #generate CSV
            csv_buffer = StringIO()
            writer = csv.writer(csv_buffer)
            writer.writerow(["ticker", "vol", "vwap", "open", "close", "high", "low", "ts", "tx"])
            
            for p in ticker_aggs:
                writer.writerow([ticker, p.volume, p.vwap, p.open, p.close, p.high, p.low, p.timestamp, p.transactions])
            
            # S3 Upload: raw/ticker/date.csv
            file_key = f"raw/{ticker}/{date_str}.csv"
            s3_client.put_object(Bucket=bucket_name, Key=file_key, Body=csv_buffer.getvalue())
            
            logging.info(f"Uploaded {ticker}. Sleeping 15s")
            time.sleep(15)

        except Exception as e:
            logging.info(f"Error {ticker}: {e}")
            continue

    return {
        'statusCode': 200,
        'body': f"Successfully processed {len(tickers)} tickers for {date_str}."
    }