#!/bin/bash

# Define variables
BUCKET_NAME="kreavana-kyc-images-$(date +%s)"
REGION="ap-southeast-1" # Change as needed
IAM_USER_NAME="kreavana-kyc-service"

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

echo "Configuring CORS policy for direct Flutter uploads"
cat <<EOF > cors.json
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT", "POST", "GET"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"]
    }
  ]
}
EOF

aws s3api put-bucket-cors \
    --bucket $BUCKET_NAME \
    --cors-configuration file://cors.json
rm cors.json

echo "Setting up S3 lifecycle policy (retain for 30 days)"
cat <<EOF > lifecycle.json
{
  "Rules": [
    {
      "ID": "DeleteOldImages",
      "Prefix": "",
      "Status": "Enabled",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket $BUCKET_NAME \
    --lifecycle-configuration file://lifecycle.json
rm lifecycle.json

echo "Creating IAM Policy for Laravel service"
cat <<EOF > policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rekognition:CompareFaces"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_ARN=$(aws iam create-policy \
    --policy-name KreavanaKycServicePolicy \
    --policy-document file://policy.json \
    --query 'Policy.Arn' --output text)
rm policy.json

echo "Creating IAM User for Laravel service"
aws iam create-user --user-name $IAM_USER_NAME

echo "Attaching Policy to IAM User"
aws iam attach-user-policy \
    --user-name $IAM_USER_NAME \
    --policy-arn $POLICY_ARN

echo "Creating Access Keys (Save these to your .env file)"
aws iam create-access-key --user-name $IAM_USER_NAME

echo "Done! Remember to update your .env with AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_BUCKET=$BUCKET_NAME"

echo "Setting up CloudWatch Billing Alarm for AWS Rekognition (assuming cost threshold $10)"
aws cloudwatch put-metric-alarm \
    --alarm-name "Rekognition-Cost-Alarm" \
    --alarm-description "Alarm when Rekognition costs exceed $10" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 21600 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD Name=ServiceName,Value=AmazonRekognition \
    --evaluation-periods 1
