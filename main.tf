


# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "AKIAXTEQ77JXUOSPHD4D"
  secret_key = "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"
}

resource "aws_instance" "project-1" {
  ami           = "ami-02e136e904f3da870"
  instance_type = "t2.micro"

  
}


# 1. create vpc

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags =  {
    name = "production"
  }
}

# 2.create Internet GW

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}

# 3.create route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route = [
      {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }
    
  ,
    {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
    }

    ]
  

  tags = {
    Name = "production"
  }
}



# 4.create subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}
# 5.Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
# 6.create security grp allow port 22,443,80

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress = [
    {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  ]
  ingress = [
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  ]
  ingress = [
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  ]

  tags = {
    Name = "allow_web"
  }
}
# 7.create Network Interface with IP created in step 4

resource "aws_network_interface" "web-server-nginx" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# 8.assign Elastic IP to network interface created  in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nginx.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}
# 9.create nginx server

resource "aws_instance" "project-1" {

  ami               = "ami-02e136e904f3da870"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name =        = "project"

  network_interface {

     device_index = 0
     network_interface_id     = aws_network_interface.web-server-nginx.id
  }


  user_data  = <<-EOF 
           #!/bin/bash
           sudo yum update -y
           sudo yum install nginx -y
           sudo systemctl start nginx 
           sudo bash -c "echo My first web server >> /var/www/html/index.html "
       EOF
            
   tags = {
         name = "web-server"
            }
}


