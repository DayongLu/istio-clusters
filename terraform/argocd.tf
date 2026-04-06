# ==========================================
# 1. Provider Requirements for ArgoCD
# ==========================================


# ==========================================
# 2. Provider Configuration for us-east-1 K8s
# ==========================================
# These providers will authenticate to the us-east-1 EKS cluster
# using the credentials from the main.tf configuration.

data "aws_eks_cluster" "cluster_use1_for_argo" {
  name = aws_eks_cluster.eks_use1.id
}

data "aws_eks_cluster_auth" "cluster_use1_for_argo" {
  name = aws_eks_cluster.eks_use1.id
}

provider "kubernetes" {
  alias                  = "k8s_use1"
  host                   = data.aws_eks_cluster.cluster_use1_for_argo.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_use1_for_argo.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_use1_for_argo.token
}

provider "helm" {
  alias = "helm_use1"
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster_use1_for_argo.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_use1_for_argo.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster_use1_for_argo.token
  }
}


