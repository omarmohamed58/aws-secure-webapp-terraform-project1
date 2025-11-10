#################################################
#                  VPC SETUP                    #
#################################################
module "main_vpc" {
  source   = "./modules/vpc"
  cidr     = var.vpc_cidr
  azs      = var.availability_zones
  tags = {
    Name       = "secure-webapp-vpc"
    ManagedBy  = "Terraform"
  }
}

#################################################
#                SUBNETS SETUP                  #
#################################################
module "subnets" {
  source              = "./modules/subnets"
  vpc_id              = module.main_vpc.id
  public_cidrs        = ["10.0.0.0/24", "10.0.2.0/24"]
  private_cidrs       = ["10.0.1.0/24", "10.0.3.0/24"]
  availability_zones  = var.availability_zones
  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

#################################################
#            INTERNET & NAT GATEWAY             #
#################################################
module "internet_gateway" {
  source = "./modules/internet_gateway"
  vpc_id = module.main_vpc.id
  tags = {
    Name       = "secure-webapp-igw"
    ManagedBy  = "Terraform"
  }
}

module "nat_gateway" {
  source           = "./modules/nat_gateway"
  subnet_id        = module.subnets.public[0]
  dependency_igw   = module.internet_gateway.id
  tags = {
    Name       = "secure-webapp-nat"
    ManagedBy  = "Terraform"
  }
}

#################################################
#               ROUTE TABLES                     #
#################################################
module "routing" {
  source             = "./modules/routing"
  vpc_id             = module.main_vpc.id
  igw_id             = module.internet_gateway.id
  nat_id             = module.nat_gateway.id
  public_subnet_ids  = module.subnets.public
  private_subnet_ids = module.subnets.private
  tags = {
    ManagedBy = "Terraform"
  }
}

#################################################
#            SECURITY GROUPS                     #
#################################################
locals {
  common_tags = { ManagedBy = "Terraform", Environment = "dev" }
}

module "sgs" {
  source = "./modules/security_groups"
  vpc_id = module.main_vpc.id
  definitions = {
    public_alb = {
      description = "HTTP/HTTPS from Internet"
      ingress = [
        { port = 80, protocol = "tcp", cidr = "0.0.0.0/0" },
        { port = 443, protocol = "tcp", cidr = "0.0.0.0/0" }
      ]
    },
    proxy = {
      description = "Traffic from Public ALB"
      ingress = [
        { port = 80, protocol = "tcp", source_sg = "public_alb" },
        { port = 22, protocol = "tcp", cidr = "0.0.0.0/0" }
      ]
    },
    internal_alb = {
      description = "Traffic from Proxies"
      ingress = [
        { port = 80, protocol = "tcp", source_sg = "proxy" },
        { port = 5000, protocol = "tcp", source_sg = "proxy" }
      ]
    },
    backend = {
      description = "Only Internal ALB"
      ingress = [
        { port = 5000, protocol = "tcp", source_sg = "internal_alb" },
        { port = 22, protocol = "tcp", source_sg = "proxy" }
      ]
      egress = [
        { from_port = 0, to_port = 0, protocol = "-1", cidr = "0.0.0.0/0" }
      ]
    }
  }
  tags = local.common_tags
}

#################################################
#                  ALBS                          #
#################################################
module "load_balancers" {
  source = "./modules/load_balancers"
  vpc_id = module.main_vpc.id
  definitions = {
    public_alb = {
      internal       = false
      subnets        = module.subnets.public
      sg_ids         = [module.sgs.public_alb_id]
      listener_port  = 80
      target_port    = 80
      health_path    = "/health"
    },
    internal_alb = {
      internal       = true
      subnets        = module.subnets.private
      sg_ids         = [module.sgs.internal_alb_id]
      listener_port  = 80
      target_port    = 5000
      health_path    = "/"
    }
  }
}

#################################################
#                    EC2                         #
#################################################
module "ec2_instances" {
  source = "./modules/ec2_instances"
  definitions = {
    proxy = {
      subnet_ids        = module.subnets.public
      sg_ids            = [module.sgs.proxy_id]
      count             = 2
      type              = "t3.micro"
      key_name          = "my-keypair"
      ssh_key_path      = "./keys/proxy.pem"
      backend_alb_dns   = module.load_balancers.internal_alb_dns
    },
    backend = {
      subnet_ids        = module.subnets.private
      sg_ids            = [module.sgs.backend_id]
      count             = 2
      type              = "t3.micro"
      key_name          = "my-keypair"
      ssh_key_path      = "./keys/backend.pem"
      local_app_path    = "./webapp"
      proxy_public_ip   = module.ec2_instances.proxy_public_ips[0]
    }
  }
}

#################################################
#                TARGET GROUPS                   #
#################################################
module "alb_targets" {
  source = "./modules/alb_targets"
  definitions = {
    public_proxy = {
      alb_arn    = module.load_balancers.public_alb_arn
      port       = 80
      protocol   = "HTTP"
      instances  = module.ec2_instances.proxy_ids
      health     = "/healthcheck"
    },
    internal_backend = {
      alb_arn    = module.load_balancers.internal_alb_arn
      port       = 5000
      protocol   = "HTTP"
      instances  = module.ec2_instances.backend_ids
      health     = "/"
    }
  }
}
