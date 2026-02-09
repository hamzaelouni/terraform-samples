resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
  tags = {
    Name        = "app-server-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

locals {
  env_config = {
    dev = {
      instance_type = "t3.micro"
      instance_count = 1
    }
    staging = {
      instance_type = "t3.small"
      instance_count = 2
    }
    prod = {
      instance_type = "t3.large"
      instance_count = 5
    }
  }

  current_env = local.env_config[terraform.workspace]
}

resource "aws_instance" "app" {
  count         = local.current_env.instance_count
  instance_type = local.current_env.instance_type
}