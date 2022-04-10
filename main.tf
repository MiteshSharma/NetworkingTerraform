provider "aws" {
  region     = var.region
  access_key = ""
  secret_key = ""
}

/*
  VPC creation for given CIDR range
*/
resource "aws_vpc" "networking" {
	cidr_block           = var.cidr_vpc
	enable_dns_support   = true
	enable_dns_hostnames = true
	tags = merge(
    {
      "Project"     = var.project_name
      "Name"        = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Internet Gateway to be used by public subnet
*/
resource "aws_internet_gateway" "networking" {
	vpc_id          = aws_vpc.networking.id
	tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Public subnet in given VPC
*/
resource "aws_subnet" "public" {
  count 				          = length(var.availability_zones)
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = element(var.subnet_public_cidr, count.index)
  map_public_ip_on_launch = "true"
  availability_zone       = element(var.availability_zones, count.index)

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table for public subnet
*/
resource "aws_route_table" "public" {
  count 		= length(var.availability_zones)
  vpc_id 		= aws_vpc.networking.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.networking.id
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table association for public subnet, connects with internet gateway
*/
resource "aws_route_table_association" "public" {
  count 		      = length(var.availability_zones)
  subnet_id       = aws_subnet.public[count.index].id
  route_table_id  = aws_route_table.public[count.index].id
}

/*
  Nat gateway EIP 
*/
resource "aws_eip" "nat_gateway" {
  count 		 = length(var.availability_zones)
  vpc = true
  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Nat gateway in public subnet.
  Best practice is to have NAT gateway in each AZ and private subnet used NAT from same AZ.
*/
resource "aws_nat_gateway" "nat_gateway" {
  count 		    = length(var.availability_zones)
  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id 	  = aws_subnet.public[count.index].id

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Private app subnet
*/
resource "aws_subnet" "private_app" {
  count 				  = length(var.subnet_private_cidr)
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = element(var.subnet_private_cidr, count.index)
  map_public_ip_on_launch = "false"
  availability_zone       = element(var.availability_zones, count.index)

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table which connects to NAT gateway in public subnet
*/
resource "aws_route_table" "private_app" {
  count 			= length(var.subnet_private_cidr)
  vpc_id 			= aws_vpc.networking.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table association to make private subnet access internet using NAT gateway
*/
resource "aws_route_table_association" "private_app" {
  count 		 = length(var.availability_zones)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

/*
  Private app DB subnet, in case we need to create any database
*/
resource "aws_subnet" "private_db" {
  count                   = length(var.subnet_private_db_cidr)
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = element(var.subnet_private_db_cidr, count.index)
  map_public_ip_on_launch = "false"
  availability_zone       = element(var.availability_zones, count.index)

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table which connects to NAT gateway in public subnet
*/
resource "aws_route_table" "private_db" {
  count       = length(var.subnet_private_db_cidr)
  vpc_id      = aws_vpc.networking.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Routing table association to make private subnet access internet using NAT gateway
*/
resource "aws_route_table_association" "private_db" {
  count           = length(var.availability_zones)
  subnet_id       = aws_subnet.private_db[count.index].id
  route_table_id  = aws_route_table.private_db[count.index].id
}

resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.networking.id
  subnet_ids = aws_subnet.public.*.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "all"
    rule_no    = 104
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 203
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "all"
    rule_no    = 204
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

resource "aws_network_acl" "private_app_nacl" {
  vpc_id     = aws_vpc.networking.id
  subnet_ids = aws_subnet.private_app.*.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "all"
    rule_no    = 104
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 203
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "all"
    rule_no    = 204
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

resource "aws_network_acl" "private_db_nacl" {
  vpc_id     = aws_vpc.networking.id
  subnet_ids = aws_subnet.private_db.*.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "all"
    rule_no    = 104
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 203
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "all"
    rule_no    = 204
    action     = "allow"
    cidr_block =  var.cidr_vpc
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  S3 bucket to store VPC flow logs
*/
resource "aws_s3_bucket" "flow_logs" {
  count         = var.enable_vpc_flow_logs
  bucket_prefix = "vpc-flow-logs-"

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}

/*
  Making S3 bucket for flow logs private with acl rule
*/
resource "aws_s3_bucket_acl" "flow_logs_bucket_acl" {
  count       = var.enable_vpc_flow_logs
  bucket      = aws_s3_bucket.flow_logs[count.index].bucket
  acl    = "private"
}

/*
  Enabling encryption on S3 bucket for flow logs
*/
resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs_bucket_encryption" {
  count       = var.enable_vpc_flow_logs
  bucket      = aws_s3_bucket.flow_logs[count.index].bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

/*
  Flow log to be captured with traffic type as REJECT
*/
resource "aws_flow_log" "flow_logs" {
  count                = var.enable_vpc_flow_logs
  traffic_type         = "REJECT"
  vpc_id               = aws_vpc.networking.id
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.flow_logs[count.index].arn

  tags = merge(
    {
      "Project"     = var.project_name
    },
    var.extra_tags,
  )
}
