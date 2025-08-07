terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = data.aws_subnets.default.ids[0]
}

resource "aws_s3_bucket" "genomic_bucket" {
  bucket = "genomic-variant-data-sydney-unique-123456"  # Ensure the bucket name is globally unique
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "aws_sns_topic" "genomic_topic" {
  name = "genomic-variant-processed-topic"
}

resource "aws_security_group" "main_sg" {
  name        = "genomic_main_sg"
  description = "Allow SSH and outbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_genomic_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "ec2_genomic_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": [
         "${aws_s3_bucket.genomic_bucket.arn}",
         "${aws_s3_bucket.genomic_bucket.arn}/*"
      ]
    },
    {
      "Action": "sns:Publish",
      "Effect": "Allow",
      "Resource": "${aws_sns_topic.genomic_topic.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_genomic_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_db_subnet_group" "db_subnet" {
  name       = "genomic-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "13.3"
  instance_class         = "db.t2.micro"
  name                   = "genomicdb"
  username               = "dbuser"
  password               = "dbpassword"
  parameter_group_name   = "default.postgres13"
  skip_final_snapshot    = true

  vpc_security_group_ids = [aws_security_group.main_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
}

resource "aws_instance" "genomic_ec2" {
  ami                    = "ami-0a709bebf4fa9246f"
  instance_type          = "t2.micro"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.main_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<EOF
#!/bin/bash
yum update -y
amazon-linux-extras install python3.8 -y
pip3 install boto3 psycopg2-binary
EOF
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.genomic_ec2.public_ip
}

output "s3_bucket" {
  description = "Name of the S3 bucket storing genomic variant files"
  value       = aws_s3_bucket.genomic_bucket.bucket
}

output "sns_topic" {
  description = "SNS topic ARN for processing notifications"
  value       = aws_sns_topic.genomic_topic.arn
}

output "rds_endpoint" {
  description = "Endpoint of the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.address
}
