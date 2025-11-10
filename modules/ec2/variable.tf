variable "resource_prefix" {
  type        = string
}

variable "vpc_identifier" {
  type        = string
}

variable "subnet_list" {
  type        = list(string)
}

variable "num_instances" {
  type        = number
}

variable "ami_selection" {
  type        = map(any)
  default = {
    name  = "amzn2-ami-hvm-*-x86_64-gp2"
    owner = "amazon"
  }
}

variable "ec2_size" {
  type        = string
}

variable "ssh_keypair_name" {
  type        = string
}

variable "ssh_private_key_file" {
  type        = string
}

variable "commands_to_run" {
  type        = list(string)
}

variable "file_to_copy" {
  type = object({
    source      = string
    destination = string
  })
  default = null
}
