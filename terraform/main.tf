# ==========================================
# 1. Providers & Global Settings
# ==========================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80.0" # Ensure a recent version that supports EKS Auto Mode
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
}

# Default provider for us-east-1
provider "aws" {
  region = "us-east-1"
}

# Aliased provider for us-east-2
provider "aws" {
  alias  = "use2"
  region = "us-east-2"
}

data "aws_caller_identity" "current" {}

# ==========================================
# 2. VPC & Subnets: us-east-1
# ==========================================
resource "aws_vpc" "use1_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "eks-auto-vpc-use1" }
}

resource "aws_subnet" "use1_subnet_a" {
  vpc_id                  = aws_vpc.use1_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Required for nodes to pull images if no NAT is used
    tags = {
      Name                   = "eks-auto-subnet-use1-a"
      "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "use1_subnet_b" {
  vpc_id                  = aws_vpc.use1_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
    tags = {
      Name                   = "eks-auto-subnet-use1-b"
      "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_internet_gateway" "use1_igw" {
  vpc_id = aws_vpc.use1_vpc.id
  tags   = { Name = "eks-auto-igw-use1" }
}

resource "aws_route_table" "use1_rt" {
  vpc_id = aws_vpc.use1_vpc.id
  tags   = { Name = "eks-auto-rt-use1" }
}

resource "aws_route" "use1_igw_route" {
  route_table_id         = aws_route_table.use1_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.use1_igw.id
}

resource "aws_route_table_association" "use1_rta_a" {
  subnet_id      = aws_subnet.use1_subnet_a.id
  route_table_id = aws_route_table.use1_rt.id
}

resource "aws_route_table_association" "use1_rta_b" {
  subnet_id      = aws_subnet.use1_subnet_b.id
  route_table_id = aws_route_table.use1_rt.id
}

# ==========================================
# 3. VPC & Subnets: us-east-2
# ==========================================
resource "aws_vpc" "use2_vpc" {
  provider             = aws.use2
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "eks-auto-vpc-use2" }
}

resource "aws_subnet" "use2_subnet_a" {
  provider                = aws.use2
  vpc_id                  = aws_vpc.use2_vpc.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
    tags = {
      Name                   = "eks-auto-subnet-use2-a"
      "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "use2_subnet_b" {
  provider                = aws.use2
  vpc_id                  = aws_vpc.use2_vpc.id
  cidr_block              = "10.2.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
    tags = {
      Name                   = "eks-auto-subnet-use2-b"
      "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_internet_gateway" "use2_igw" {
  provider = aws.use2
  vpc_id   = aws_vpc.use2_vpc.id
  tags     = { Name = "eks-auto-igw-use2" }
}

resource "aws_route_table" "use2_rt" {
  provider = aws.use2
  vpc_id   = aws_vpc.use2_vpc.id
  tags     = { Name = "eks-auto-rt-use2" }
}

resource "aws_route" "use2_igw_route" {
  provider               = aws.use2
  route_table_id         = aws_route_table.use2_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.use2_igw.id
}

resource "aws_route_table_association" "use2_rta_a" {
  provider       = aws.use2
  subnet_id      = aws_subnet.use2_subnet_a.id
  route_table_id = aws_route_table.use2_rt.id
}

resource "aws_route_table_association" "use2_rta_b" {
  provider       = aws.use2
  subnet_id      = aws_subnet.use2_subnet_b.id
  route_table_id = aws_route_table.use2_rt.id
}

# ==========================================
# 4. VPC Peering (us-east-1 <-> us-east-2)
# ==========================================
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.use1_vpc.id
  peer_vpc_id = aws_vpc.use2_vpc.id
  peer_region = "us-east-2"
  auto_accept = false
  tags        = { Name = "use1-to-use2-peering" }
}

resource "aws_vpc_peering_connection_accepter" "peer_accepter" {
  provider                  = aws.use2
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
  tags                      = { Name = "use1-to-use2-peering-accepter" }
}

resource "aws_route" "use1_to_use2_route" {
  route_table_id            = aws_route_table.use1_rt.id
  destination_cidr_block    = aws_vpc.use2_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "use2_to_use1_route" {
  provider                  = aws.use2
  route_table_id            = aws_route_table.use2_rt.id
  destination_cidr_block    = aws_vpc.use1_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# ==========================================
# 5. Global IAM Roles for EKS Auto Mode
# ==========================================
# EKS Auto mode requires specific managed policies appended to the cluster role.
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-auto-mode-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

locals {
  cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  ]
}

resource "aws_iam_role_policy_attachment" "cluster_policies_attach" {
  count      = length(local.cluster_policies)
  policy_arn = local.cluster_policies[count.index]
  role       = aws_iam_role.eks_cluster_role.name
}

# Node Role for EKS Auto Mode Instances
resource "aws_iam_role" "eks_node_role" {
  name = "eks-auto-mode-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

locals {
  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  ]
}

resource "aws_iam_role_policy_attachment" "node_policies_attach" {
  count      = length(local.node_policies)
  policy_arn = local.node_policies[count.index]
  role       = aws_iam_role.eks_node_role.name
}

# ==========================================
# 6. EKS Cluster: us-east-1
# ==========================================
resource "aws_eks_cluster" "eks_use1" {
  name     = "eks-auto-cluster-use1"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = [aws_subnet.use1_subnet_a.id, aws_subnet.use1_subnet_b.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Required to be explicitly disabled for Auto Mode
  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_node_role.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies_attach
  ]
}

# ==========================================
# 7. EKS Cluster: us-east-2
# ==========================================
resource "aws_eks_cluster" "eks_use2" {
  provider = aws.use2
  name     = "eks-auto-cluster-use2"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = [aws_subnet.use2_subnet_a.id, aws_subnet.use2_subnet_b.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Required to be explicitly disabled for Auto Mode
  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_node_role.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies_attach
  ]
}

# ==========================================
# 8. Inter-VPC Security Group Rules
# ==========================================
# Allow all traffic from the peered VPC in the other region.

resource "aws_security_group_rule" "use1_allow_use2_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_vpc.use2_vpc.cidr_block]
  security_group_id = aws_eks_cluster.eks_use1.vpc_config[0].cluster_security_group_id
  description       = "Allow all traffic from use2 VPC"
}

resource "aws_security_group_rule" "use2_allow_use1_all" {
  provider          = aws.use2
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_vpc.use1_vpc.cidr_block]
  security_group_id = aws_eks_cluster.eks_use2.vpc_config[0].cluster_security_group_id
  description       = "Allow all traffic from use1 VPC"
}
