provider "aws" {}

variable vpc_cidr_block {}
variable sibnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

variable "private-ips" {
    default = {
        0 = "10.0.10.10"
        1 = "10.0.10.20"
        2 = "10.0.10.30"
        3 = "10.0.10.40"
        4 = "10.0.10.50"
    }
}

resource "aws_vpc" "dev-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "dev-subnet-1" {
    vpc_id = aws_vpc.dev-vpc.id
    cidr_block = var.sibnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "dev_igw" {
    vpc_id = aws_vpc.dev-vpc.id
    tags = {
        Name: "${var.env_prefix}-igw"
    }
}

resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.dev-vpc.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.dev_igw.id
    }
    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}

resource "aws_default_security_group" "default-secgroup" {
    vpc_id = aws_vpc.dev-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-default-secgroup"
    }
}

data "aws_ami" "centos_9" {
    most_recent = true
    filter {
        name = "name"
        values = ["CentOS Stream 9*"]
    }
    filter {
        name = "architecture"
        values = ["x86_64"]
    }
}

resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.public_key_location)
}

data "template_file" "user_data" {
  template = file("cloud-init.yaml")
}

resource "aws_instance" "RS-control-server" {
    ami = data.aws_ami.centos_9.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-secgroup.id]
    associate_public_ip_address = true
    private_ip = lookup(var.private-ips,0)
    availability_zone = var.avail_zone
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name: "${var.env_prefix}-control-server"
    }

    user_data = data.template_file.user_data.rendered
}

output "control_server_public_ip" {
    value = aws_instance.RS-control-server.public_ip
}

output "haproxy_server_public_ip" {
    value = aws_instance.RS-haproxy-server.public_ip
}

resource "aws_instance" "RS-haproxy-server" {
    ami = data.aws_ami.centos_9.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-secgroup.id]
    associate_public_ip_address = true
    availability_zone = var.avail_zone
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name: "${var.env_prefix}-haproxy-server"
    }
}

resource "aws_instance" "RS-apache-server" {
    ami = data.aws_ami.centos_9.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-secgroup.id]
    associate_public_ip_address = true
    private_ip = lookup(var.private-ips,2)
    availability_zone = var.avail_zone
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name: "${var.env_prefix}-apache-server"
    }
}

resource "aws_instance" "RS-apache-server-2" {
    ami = data.aws_ami.centos_9.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-secgroup.id]
    associate_public_ip_address = true
    private_ip = lookup(var.private-ips,3)
    availability_zone = var.avail_zone
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name: "${var.env_prefix}-apache-server"
    }
}

resource "aws_instance" "RS-apache-server-3" {
    ami = data.aws_ami.centos_9.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-secgroup.id]
    associate_public_ip_address = true
    private_ip = lookup(var.private-ips,4)
    availability_zone = var.avail_zone
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name: "${var.env_prefix}-apache-server"
    }
}

resource "aws_s3_bucket" "s3_bucket" {
    bucket = "rs-s3-bucket"
    tags = {
        Name = "rs-s3-bucket"
    }
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  acl    = "private"
}

resource "aws_s3_object" "ansible_upload" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  key = "rs-demo.tgz"
  source = "/home/sana/RS-ansible/rs-demo.tgz"
  etag   = "${filemd5("/home/sana/RS-ansible/rs-demo.tgz")}"
}

resource "aws_s3_object" "haproxy_cfg_upload" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  key = "haproxy.cfg"
  source = "/home/sana/RS-haproxy/haproxy.cfg"
  etag   = "${filemd5("/home/sana/RS-haproxy/haproxy.cfg")}"
}