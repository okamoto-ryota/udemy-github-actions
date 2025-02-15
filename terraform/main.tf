terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = {
      provision  = "terraform"
      created_by = var.emp_id
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.emp_id}_vpc_main"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = "${var.region}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.emp_id}_subnet_public"
  }
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.emp_id}_rtb_main"
  }
}

resource "aws_route_table_association" "public_rtb" {
  route_table_id = aws_route_table.rtb.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.emp_id}_igw_main"
  }
}

resource "aws_route" "rtb_igw_route" {
  route_table_id         = aws_route_table.rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

data "aws_ami" "ec2_main" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-0ac6b9b2908f3e20d"] # Ubuntu 22.04(amd64)
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ec2_main" {
  ami                         = data.aws_ami.ec2_main.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_main.id]
  key_name                    = aws_key_pair.ssh_ec2_main.key_name

  tags = {
    Name = "${var.emp_id}_ec2_main"
  }
  depends_on = [aws_security_group.ec2_main]
}

resource "aws_security_group" "ec2_main" {
  name   = "${var.emp_id}_sg_ec2_main"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.emp_id}_sg_ec2_main"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_main_allow_ssh" {
  security_group_id = aws_security_group.ec2_main.id
  cidr_ipv4         = var.allowed_ipv4_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22

  tags = {
    Name = "${var.emp_id}_in_rule_allow_ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_main_allow_http" {
  security_group_id = aws_security_group.ec2_main.id
  cidr_ipv4         = var.allowed_ipv4_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80

  tags = {
    Name = "${var.emp_id}_in_rule_allow_http"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_main_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ec2_main.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports

  tags = {
    Name = "${var.emp_id}_eg_rule_allow_all_traffic_ipv4"
  }
}

resource "aws_key_pair" "ssh_ec2_main" {
  key_name   = "${var.emp_id}_key_pair_ssh_ec2_main"
  public_key = file(var.ssh_pubkey_ec2_main)

  tags = {
    Name = "${var.emp_id}_key_pair_ssh_ec2_main"
  }
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.emp_id}-udemy-github-actions-s3"

  tags = {
    Name = "${var.emp_id}_frontend_bucket"
  }
}

resource "aws_iam_policy" "github_actions_s3" {
  name = "${var.emp_id}-udemy-github-actions-frontend-deployment-policy"
  policy = jsonencode({
    Statement = [
      {
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = aws_s3_bucket.frontend.arn
        Sid      = "VisualEditor0"
      },
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Sid      = "VisualEditor1"
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role" "github_actions" {
  name = "${var.emp_id}-udemy-github-actions-frontend-deployment-role"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:okamoto-ryota/udemy-github-actions:ref:refs/heads/main"
          }
        }
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::527412143144:oidc-provider/token.actions.githubusercontent.com"
        }
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}
