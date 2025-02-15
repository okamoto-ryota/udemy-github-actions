variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-1"
}

variable "profile" {
  type        = string
  description = "AWS profile"
}

variable "emp_id" {
  type        = string
  description = "Prefix for the name of the resources"
}

variable "allowed_ipv4_cidr_block" {
  type        = string
  description = "IPv4 CIDR block to allow access to AWS"
}

variable "ssh_pubkey_ec2_main" {
  type        = string
  description = "path to the SSH public key file"
}
