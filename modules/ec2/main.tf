data "aws_ami" "selected" {
  most_recent = true
  filter {
    name = "name"
    values = [lookup(var.ami_filter, "name", "*")]
  }
  owners = [lookup(var.ami_filter, "owner", "amazon")]
}

resource "aws_security_group" "inst_sg" {
  name = "${var.name_prefix}-sg"
  vpc_id = var.vpc_id != null ? var.vpc_id : null
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # TODO: configure flask to run on port 80
  # or get security group ports from variable
  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "this" {
  count = var.instance_count
  ami = data.aws_ami.selected.id
  instance_type = var.instance_type
  subnet_id = element(var.subnet_ids, count.index)
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.inst_sg.id]
  associate_public_ip_address = true
  tags = { Name = "${var.name_prefix}-${count.index + 1}" }

  provisioner "file" {
    source      = var.copy_file.source
    destination = var.copy_file.destination

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.ssh_private_key_path)
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = var.remote_commands
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file(var.ssh_private_key_path)
      host = self.public_ip
    }
  }
}

