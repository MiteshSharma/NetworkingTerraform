# VPC Network with Terraform

We are creating network layer on AWS using terraform. We are creating this in two availability zones. In each availability zone, we have three subnets. One subnet is public that have internet gateway attached to it with NAT gateway deployed inside to provide other private subnets internet access from inside. We have two private subnet, one for deploying all EC2 instances and other is mainly for deploying database layer.

## Deployed items:

1. VPC
2. Subnet: 3 subnets, 1 public and 2 private
3. Internet Gateway: Internet gateway associated with public subnet
4. Route table
5. Route table association
6. NAT Gateway
7. Elastic IP for NAT Gateway
8. Network ACL: As network ACL are stateless, so we have to expose both ingress and egress for a port to let traffic come and go. We are exposing port 80, 443, 22, any traffic from internal VPC CIDR and any port between 1024 and 65535. 
9. S3 bucket for flow logs with encrypted and private bucket
10. Flow logs to S3

## Terraform commands:

terraform init

terraform plan

terraform apply

terraform destroy

More details about terraform: https://www.terraform.io 