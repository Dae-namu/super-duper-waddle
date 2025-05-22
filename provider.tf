terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.96.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.11.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Helm Chart Repository 추가
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}