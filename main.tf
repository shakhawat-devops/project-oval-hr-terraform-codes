# Configure the AWS Provider
provider "aws" {
   region  = var.region
}

# Create a custom VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Project = "DevOps-Challenge"
    Name = "Test VPC"
 }
}

# Create Public Subnet1 in Test VPC
resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub_sub1_cidr_block
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Project = "DevOps-Challenge"
     Name = "public_subnet1"
 
 }
}

# Create Private Subnet1 in Test VPC
resource "aws_subnet" "prv_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.prv_sub1_cidr_block
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Project = "Devops-Challenge"
    Name = "private_subnet1" 
 }
}

# Create Internet Gateway in Test VPC

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Project = "Devops-Challenge"
    Name = "internet gateway" 
 }
}

# Create Public Route Table in Test VPC

resource "aws_route_table" "pub_sub1_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Project = "DevOps-Challenge"
    Name = "public subnet route table" 
 }
}

# Create route table association of public subnet1 in Test VPC
resource "aws_route_table_association" "internet_for_pub_sub1" {
  route_table_id = aws_route_table.pub_sub1_rt.id
  subnet_id      = aws_subnet.pub_sub1.id
}

# Create EIP for NAT GW1 
  resource "aws_eip" "eip_natgw1" {
  count = "1"
}

# Create NAT gateway1 in Test VPC and in public subnet1

resource "aws_nat_gateway" "natgateway_1" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw1[count.index].id
  subnet_id     = aws_subnet.pub_sub1.id
}


# Create private route table for private subnet1

resource "aws_route_table" "prv_sub1_rt" {
  count  = "1"
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_1[count.index].id
  }
  tags = {
    Project = "DevOps-Challenge"
    Name = "private subnet1 route table" 
 }
}

# Create route table association betn private subnet1 & NAT GW1

resource "aws_route_table_association" "pri_sub1_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub1_rt[count.index].id
  subnet_id      = aws_subnet.prv_sub1.id
}


# Create security group for Bastion Host

resource "aws_security_group" "bsh_sg" {
  name        = var.sg_bs_name
  description = var.sg_bs_description
  vpc_id      = aws_vpc.main.id

ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
 
 tags = {
    Name = var.sg_bs_tagname
    Project = "DevOps-Challenge" 
  }	
}

# Create security group for webserver (laravel)

resource "aws_security_group" "webserver_sg" {
  name        = var.sg_ws_name
  description = var.sg_ws_description
  vpc_id      = aws_vpc.main.id

ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]

 }

ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

 tags = {
    Name = var.sg_ws_tagname 
    Project = "DevOps-Challenge"
  }
}

#Create private Ec2 instances in private subnet
resource "aws_network_interface" "ni" {
  subnet_id   = aws_subnet.prv_sub1.id
  security_groups = [aws_security_group.webserver_sg.id]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface" "nii" {
  subnet_id   = aws_subnet.pub_sub1.id
  security_groups = [aws_security_group.bsh_sg.id]

  tags = {
    Name = "primary_network_interface"
  }
}

#Taking the latest ubuntu image for servers

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#Create a Bastion host to SSH in our private web server with ubuntu image
resource "aws_instance" "bastionHost" {

  ami = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.pub_sub1.id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  availability_zone = "us-east-1a"
  key_name = "prod-app"

  tags = {
    Name = "BastionHost"
  }

}

#Create webserver private ec2 instance in Test VPC and in private subnet1 with ubuntu image
resource "aws_instance" "ubuntu" {

  ami = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.prv_sub1.id
  instance_type = "t2.micro"
  associate_public_ip_address = false
  availability_zone = "us-east-1a"
  key_name = "prod-app"
  user_data = file("./userdata.sh")

  tags = {
    Name = "WebServer_Laravel"
  }

}

#Attaching security group for webserver to allow http and ssh traffic
resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.webserver_sg.id
  network_interface_id = aws_instance.ubuntu.primary_network_interface_id
}

#Attaching security group for Bastion host to allow ssh traffic
resource "aws_network_interface_sg_attachment" "sg_attachment1" {
  security_group_id    = aws_security_group.bsh_sg.id
  network_interface_id = aws_instance.bastionHost.primary_network_interface_id
}

# Create Target group for NLB
resource "aws_lb_target_group" "TG-tf" {
  name     = "Demo-TargetGroup-tf"
  port     = 80
  protocol = "TCP"
  vpc_id   = "${aws_vpc.main.id}"
  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
  }
}

#Attaching instance in the target group
resource "aws_lb_target_group_attachment" "TG-tf-attach" {
  target_group_arn = aws_lb_target_group.TG-tf.arn
  target_id        = aws_instance.ubuntu.id
  port             = 80
}

# Create Network Load Balancer to expose application in 80 port 
resource "aws_lb" "NLB-tf" {
  name               = "Demo-NLB-tf"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "network"
  subnets            = [aws_subnet.pub_sub1.id]
  #enable_deletion_protection = true

  tags = {
	  name  = "Demo-AppLoadBalancer-tf"
    Project = "DevOps-Challenge"
    Environment = "Dev"
  }
}

# Create NLB Listener 

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.NLB-tf.arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG-tf.arn
  }
  depends_on = ["aws_lb_target_group.TG-tf"]
}
