variable "rules" {
  default = [
    {
      port = 80
      proto = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port = 22
      proto = "tcp"
      cidr_blocks = ["1.2.3.4/32"]}
  ]
}

resource "aws_security_group" "my_sg" {
  name = "my_sg"
  dynamic "ingress" {
    for_each = var.rules
    content {
      from_port   =  ingress.value["port"]
      to_port     =  ingress.value["port"]
      protocol    =  ingress.value["proto"]
      cidr_blocks =  ingress.value["cidr_blocks"]
    }
  }
}