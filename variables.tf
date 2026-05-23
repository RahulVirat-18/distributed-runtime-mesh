variable "aws_region" {
  description = "The AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment_tag" {
  description = "Tag name used to identify assignment infrastructure"
  type        = string
  default     = "AIchemyst-Inference-Grid"
}

variable "gateway_instance_type" {
  description = "EC2 instance size for the public API Gateway and engine coordinator"
  type        = string
  default     = "t2.micro"
}

variable "worker_instance_type" {
  description = "EC2 instance size for the private Python and TypeScript workers"
  type        = string
  default     = "t2.micro"
}