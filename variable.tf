variable "aws_region" {
  description = "declering the aws region"
  type        = string
}

variable "aws_profile" {
  description = "AWS Profile"
  type        = string
}

variable "Environment" {
  type    = string
}

variable "default-tags" {
  type = map(string)
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}
