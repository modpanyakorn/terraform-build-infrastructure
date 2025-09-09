# Create VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dev_vpc"
  }
}

# Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "igw"
  }
}

# Crate public-subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

# Crate private-subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private_subnet"
  }
}

# Create Route Table public-subent route to external throught igw
resource "aws_route_table" "allow_traffic_public_subnet_to_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # route to External (Internet)
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "allow_traffic_public_subnet_to_igw"
  }
}

# Create Route Association (public_subnet to igw)
resource "aws_route_table_association" "public_subnet_route_to_igw" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.allow_traffic_public_subnet_to_igw.id
}

# Create Elastic IP 
resource "aws_eip" "elastic_ip" {
  tags = {
    Name = "nat_ip"
  }
}

# Cratet NAT gateway in public-subnet
resource "aws_nat_gateway" "nat_public_subnet" {
  subnet_id     = aws_subnet.public_subnet.id
  allocation_id = aws_eip.elastic_ip.id
  tags = {
    Name = "nat_public_subnet"
  }
}

# Create route table private-subnet to nat gateway
resource "aws_route_table" "allow_traffic_private_subnet_to_nat" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_public_subnet.id
  }

  tags = {
    Name = "allow_traffic_private_subnet_to_nat"
  }
}

# Create route association (private-subnet to nat)
resource "aws_route_table_association" "private_subnet_route_tonat" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.allow_traffic_private_subnet_to_nat.id
}

# Create Security Group using in public-subnet
resource "aws_security_group" "allow_traffic_public_subnet" {
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public_subnet_security_group"
  }
}

# Create Security Group using in private-subnet
resource "aws_security_group" "allow_traffic_private_subnet" {
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # cidr_blocks = [aws_subnet.public_subnet.cidr_block]
    security_groups = [aws_security_group.allow_traffic_public_subnet.id] # Allow Traffic from Instances that only using SG (allow_traffic_public_subnet)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_subnet_security_group"
  }
}

# Create Key Pair
resource "tls_private_key" "rsa_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create Key name in AWS
resource "aws_key_pair" "ssh_key_name" {
  key_name   = "ssh_key_name"
  public_key = tls_private_key.rsa_ssh_key.public_key_openssh
}

# Create Instances in public-subet
resource "aws_instance" "frontend_vm" {
  ami                    = "ami-0933f1385008d33c4"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_traffic_public_subnet.id]
  key_name               = aws_key_pair.ssh_key_name.key_name
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo '${tls_private_key.rsa_ssh_key.private_key_pem}' > /home/ubuntu/private_key_to_backend_vm.pem
    chown ubuntu:ubuntu /home/ubuntu/private_key_to_backend_vm.pem
    chmod 400 /home/ubuntu/private_key_to_backend_vm.pem
  EOF
  )

  tags = {
    Name = "frontend_vm"
  }
}

# Create Instances in private-subnet
resource "aws_instance" "backend_vm" {
  ami                    = "ami-0933f1385008d33c4"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_traffic_private_subnet.id] # Terraform recommend use "vpc_security_group_ids" than "security_groups"
  key_name               = aws_key_pair.ssh_key_name.key_name
  tags = {
    Name = "backend_vm"
  }
}
