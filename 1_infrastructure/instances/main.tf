// Set cloud provider
provider "aws" {
    region = "us-east-1"
}

// Set a VPC with a custom ip address
resource "aws_vpc" "Main" {
    cidr_block = "192.168.0.0/16"
    enable_dns_hostnames = true

    tags = {
      Name = "Main"
    }
}

// Set a public subnet

resource "aws_subnet" "Public_Subnet_A" {
    vpc_id = aws_vpc.Main.id
    availability_zone = "us-east-1a"
    cidr_block = "192.168.10.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "Public Subnet A"
    }
  
}

// Set a public subnet

resource "aws_subnet" "Public_Subnet_B" {
    vpc_id = aws_vpc.Main.id
    availability_zone = "us-east-1b"
    cidr_block = "192.168.20.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "Public Subnet B"
    }
  
}

// Set a private subnet

resource "aws_subnet" "Private_Subnet" {
    vpc_id = aws_vpc.Main.id
    availability_zone = "us-east-1c"
    cidr_block = "192.168.30.0/24"

    tags = {
        Name = "Private Subnet"
    }
  
}

// Set an internet gateway

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.Main.id

    tags = {
      Name = "internet_gateway"
    }
  
}

// Set a NAT gateway

// First we need EIP (Elastic IP Public)

resource "aws_eip" "Elastic_IP" {
    vpc = true
    depends_on = [aws_internet_gateway.igw]
  
}

// Set nat gw

resource "aws_nat_gateway" "natgw" {
    
    allocation_id = aws_eip.Elastic_IP.id
    subnet_id = aws_subnet.Public_Subnet_C

    tags = {
        Name = "nat gw"
    }

    depends_on = [aws_internet_gateway.igw]
  
}

// Set a public route table

resource "aws_route_table" "Public_Route_Table" {

    vpc_id = aws_vpc.Main.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "Public Route Table"
    }
  
}

// Set a private route table

resource "aws_route_table" "Private_Route_Table" {

    vpc_id = aws_vpc.Main.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
    }

    tags = {
        Name = "Private Route Table"
    }
  
}

// Set main route table

resource "aws_main_route_table_association" "Main_Route_Table" {
    vpc_id = aws_vpc.Main.id
    route_table_id = aws_route_table.Public_Route_Table.id  
}

// Set specific route table to private subnet

resource "aws_route_table_association" "Private_Association" {
    subnet_id = aws_subnet.Private_Subnet.id
    route_table_id = aws_route_table.Private_Route_Table.id 
}

// Create a security group with access to internet

resource "aws_security_group" "Internet_Access_Security_Group" {
    name = "internet access security group"
    vpc_id = aws_vpc.Main.id

    ingress = [ {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "permit inbound all traffic"
      from_port = 0
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      protocol = "-1"
      security_groups = []
      self = false
      to_port = 0
    }

    ]

    egress = [ {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "permit outbound traffic"
      from_port = 0
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      protocol = "-1"
      security_groups = []
      self = false
      to_port = 0
    } ]
  
}

// Create an instance for Web Application

resource "aws_instance" "Web" {

    //free tier ubuntu ami
    ami = "ami-04505e74c0741db8d"
    instance_type = "t2.micro"
    private_ip = "192.168.10.10"

    key_name = "RobinFoodTest"

    user_data = "${file("./scripts/front.sh")}"

    tags = {
        Name = "Web Server"
    }

    subnet_id = aws_subnet.Public_Subnet_A.id
    vpc_security_group_ids = [aws_security_group.Internet_Access_Security_Group.id]

    depends_on = [
      aws_instance.Api
    ]
  
}

// Create an instance for Api Tier

resource "aws_instance" "Api" {

    //free tier ubuntu ami
    ami = "ami-04505e74c0741db8d"
    instance_type = "t2.micro"
    private_ip = "192.168.30.10"

    key_name = "RobinFoodTest"

    user_data = "${file("./scripts/back.sh")}"

    tags = {
        Name = "Api Server"
    }

    subnet_id = aws_subnet.Private_Subnet.id
    vpc_security_group_ids = [aws_security_group.Internet_Access_Security_Group.id]

    depends_on = [
        aws_route_table_association.Private_Association
        ]
  
}

// AutoScaling and Load Balancer Configuration for Web application

// Set launch configuration

resource "aws_launch_configuration" "Web_launch_config" {
    name_prefix = "launch-for-web-server"
    image_id = "ami-04505e74c0741db8d"
    instance_type = "t2.micro"
    user_data = "${file("./scripts/front.sh")}"

    security_groups = [aws_security_group.web-sg.id]

    lifecycle {
      create_before_destroy = true
    }
  
}

// Set Securitys groups to instance and load balancer

resource "aws_security_group" "web-sg" {
  name = "security-group-to-web-server"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer-sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_balancer-sg.id]
  }

  vpc_id = aws_vpc.Main.id
}

resource "aws_security_group" "load_balancer-sg" {
  name = "security-group-to-load-balancer"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.Main.id
}

// Set ASG

resource "aws_autoscaling_group" "WEB_ASG" {
    min_size = 1
    max_size = 2
    desired_capacity = 1
    launch_configuration = aws_launch_configuration.Web_launch_config.name
    vpc_zone_identifier =  [aws_subnet.Public_Subnet_A.id, aws_subnet.Public_Subnet_B.id]
}

// Set LB

resource "aws_lb" "Load_Balancer" {

    name = "application-load-balancer"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.load_balancer-sg.id]
    subnets = [aws_subnet.Public_Subnet_A.id, aws_subnet.Public_Subnet_B.id]
}

// Set LB listener

resource "aws_lb_listener" "lb_listener" {
    load_balancer_arn = aws_lb.Load_Balancer.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.lb_target_group.arn
    }
  
}

// Set LB target group

resource "aws_lb_target_group" "lb_target_group" {
    name = "lb-target-group"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.Main.id
}

// Attach ASG to ALB

resource "aws_autoscaling_attachment" "asg_attachment" {
    autoscaling_group_name = aws_autoscaling_group.WEB_ASG.id
    lb_target_group_arn = aws_lb_target_group.lb_target_group.arn
}

// RDS MySQL

# resource "aws_subnet" "Private_DB" {
#   vpc_id = aws_vpc.Main.id
#   availability_zone = "us-east-1d"
#   cidr_block = "192.168.40.0/24"

#     tags = {
#         Name = "DB Subnet"
#     }
# }

# resource "aws_security_group" "DB-sg" {
#     name = "database-sg"
#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = ["192.168.30.10/32"]
#   }
#   vpc_id = aws_vpc.Main.id
  
# }

# resource "aws_db_instance" "MySQL_Instance" {
#     subnet_id = aws_subnet.Private_DB.id
#     allocated_storage    = 10
#     engine               = "mysql"
#     engine_version       = "5.7"
#     instance_class       = "db.t3.micro"
#     name                 = "movie_db"
#     username             = "applicationuser"
#     password             = "applicationuser"
#     skip_final_snapshot  = true

#     vpc_security_group_ids = [aws_security_group.DB-sg.id]
# }