provider "aws" {
  region = "ap-south-1"
}


variable "subnet_prefix" {
    description = "cidr block for subnet"
    type = string
}


# 1. Create VPC
resource "aws_vpc" "prodvpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "Production_VPC"
    }
}

# 2. IGW
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prodvpc.id  

    tags = {
      Name = "Prod_IGW"
    }
}

# 3. RT
resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prodvpc.id

    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
      Name = "Prod_Route_table"
    }
}

# 4. Subnet
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prodvpc.id
    cidr_block = var.subnet_prefix
    availability_zone = "ap-south-1a"

    tags = {
      Name = "Prod_subnet"
    }
}

# 5. Associate RT
resource "aws_route_table_association" "prodrtas" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
  
}

# 6. Security group
resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"
    description = "allow web  traffic"
    vpc_id = aws_vpc.prodvpc.id

    tags = {
      Name = "Prod-SG"
    }


    ingress  {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress  {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress  {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
        description = "Allow traffic"
        protocol = -1
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# 7. Network interface
resource "aws_network_interface" "webservernic" {
    subnet_id = aws_subnet.subnet-1.id
    security_groups = [aws_security_group.allow_web.id]
    private_ips = ["10.0.1.50"]

    tags = {
      Name = "Network_interface"
    }
}

# 8. EIP
resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.webservernic.id
    associate_with_private_ip = "10.0.1.50" 
    depends_on =  [aws_internet_gateway.gw]

    tags = {
      Name = "Prod_EIP"
    }
}

output "Server_Public_IP" {
    value = aws_eip.one.public_ip
}

# 9. server  creation and install appache
resource "aws_instance" "webserver" {
    ami = "ami-09a7bbd08886aafdf"
    instance_type = "t2.micro"
    availability_zone = "ap-south-1a"
    key_name = "terraform-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.webservernic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo yum update
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                echo "<h1>Hello Mr.SHARATHKUMAR Welcome to Terraform</h1>" | sudo tee /var/www/html/index.html
                EOF

    tags = {
      Name = "Web-server"
    }
  
}

output "Server_Private_IP" {
    value = aws_instance.webserver.private_ip
}

output "Server_ID" {
    value = aws_instance.webserver.id
}

output "Server_state" {
    value = aws_instance.webserver.instance_state
}

 
