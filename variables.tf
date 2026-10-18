variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g. dev, prod)"
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "koba-eks-cluster"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for EKS worker nodes"
  default     = ["t3.medium"]
}

variable "desired_nodes" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "min_nodes" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "max_nodes" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 4
}
