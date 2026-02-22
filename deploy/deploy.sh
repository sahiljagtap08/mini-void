#!/bin/bash
set -e

ACCOUNT_ID=855299048881
REGION=us-east-1
REPO_NAME=mini-void
CLUSTER=mini-void-cluster
SERVICE=mini-void-service
TASK_FAMILY=mini-void-task
DIR="$(cd "$(dirname "$0")/.." && pwd)"

ECR_URI=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME

echo ""
echo "=== 1. Create ECR repository ==="
aws ecr create-repository --repository-name $REPO_NAME --region $REGION \
  2>/dev/null && echo "Created." || echo "Already exists."

echo ""
echo "=== 2. Build and push Docker image ==="
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t $REPO_NAME $DIR
docker tag $REPO_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo ""
echo "=== 3. Store API key in SSM ==="
API_KEY=$(grep OPENAI_API_KEY $DIR/.env | cut -d= -f2)
aws ssm put-parameter \
  --name "/mini-void/OPENAI_API_KEY" \
  --value "$API_KEY" \
  --type "SecureString" \
  --region $REGION \
  --overwrite \
  2>/dev/null && echo "Stored." || echo "Updated."

echo ""
echo "=== 4. Create ECS task execution role ==="
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  2>/dev/null && echo "Role created." || echo "Role already exists."

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
  2>/dev/null || true

aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name SSMReadPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["ssm:GetParameters", "ssm:GetParameter"],
      "Resource": "arn:aws:ssm:'"$REGION"':'"$ACCOUNT_ID"':parameter/mini-void/*"
    }]
  }'
echo "IAM policies attached."

echo ""
echo "=== 5. Create ECS cluster ==="
aws ecs create-cluster --cluster-name $CLUSTER --region $REGION \
  2>/dev/null && echo "Cluster created." || echo "Already exists."

echo ""
echo "=== 6. Register task definition ==="
aws ecs register-task-definition \
  --region $REGION \
  --family $TASK_FAMILY \
  --requires-compatibilities FARGATE \
  --network-mode awsvpc \
  --cpu 256 \
  --memory 512 \
  --execution-role-arn arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole \
  --container-definitions '[{
    "name": "mini-void",
    "image": "'"$ECR_URI"':latest",
    "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
    "secrets": [{
      "name": "OPENAI_API_KEY",
      "valueFrom": "arn:aws:ssm:'"$REGION"':'"$ACCOUNT_ID"':parameter/mini-void/OPENAI_API_KEY"
    }],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/mini-void",
        "awslogs-region": "'"$REGION"'",
        "awslogs-stream-prefix": "ecs",
        "awslogs-create-group": "true"
      }
    }
  }]' > /dev/null
echo "Task definition registered."

echo ""
echo "=== 7. Networking ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text --region $REGION)
echo "VPC: $VPC_ID"

SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[0].SubnetId' \
  --output text --region $REGION)
echo "Subnet: $SUBNET_ID"

SG_ID=$(aws ec2 create-security-group \
  --group-name mini-void-sg \
  --description "Mini Void - allow port 8000" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null) || \
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=mini-void-sg Name=vpc-id,Values=$VPC_ID \
  --query 'SecurityGroups[0].GroupId' \
  --output text --region $REGION)
echo "Security group: $SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8000 \
  --cidr 0.0.0.0/0 \
  --region $REGION \
  2>/dev/null && echo "Port 8000 opened." || echo "Rule already exists."

echo ""
echo "=== 8. Create ECS service ==="
aws ecs create-service \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --task-definition $TASK_FAMILY \
  --launch-type FARGATE \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --region $REGION > /dev/null \
  2>/dev/null && echo "Service created." || echo "Service already exists."

echo ""
echo "=== Waiting for task to start (30s) ==="
sleep 30

TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --query 'taskArns[0]' \
  --output text --region $REGION)

ENI_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ARN \
  --region $REGION \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text --region $REGION)

echo ""
echo "✓ Live at: http://$PUBLIC_IP:8000"
