variable "project_prefix" {
  description = "Prefix used for all resources in this project"
  type        = string
}

variable "vpc" {
  description = "VPC identifier where resources will be deployed"
  type        = string
}

variable "alb_identifier" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

variable "target_suffix" {
  description = "Suffix used for naming the target group"
  type        = string
}

variable "port_target" {
  description = "Port on EC2 instances to send traffic"
  type        = number
}

variable "protocol_target" {
  description = "Protocol used by target group"
  type        = string
  default     = "HTTP"
}

variable "listener_port" {
  description = "Port where ALB listener accepts connections"
  type        = number
}

variable "listener_protocol" {
  description = "Protocol used by ALB listener"
  type        = string
  default     = "HTTP"
}

variable "health_path" {
  description = "HTTP path used by health checks"
  type        = string
  default     = "/"
}

variable "instance_list" {
  description = "List of EC2 instance IDs to register in the target group"
  type        = list(string)
}

variable "common_tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
