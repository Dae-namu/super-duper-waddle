# EKS 클러스터를 생성 (EKS 클러스터 IAM 역할 사용)
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

# 기본적인 Fargate 환경 구성
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = local.cluster_name
  fargate_profile_name   = "fp-default"
  depends_on             = [aws_eks_cluster.this]
  pod_execution_role_arn = aws_iam_role.pod_execution.arn
  subnet_ids             = aws_subnet.private[*].id
  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
}

# EC2 기반 Node Group 구성
resource "aws_eks_node_group" "this" {
  cluster_name    = local.cluster_name
  node_group_name = "ng-ec2"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
}

# EKS 인증 및 Provider 연동
data "aws_eks_cluster_auth" "cluster" {
  name       = aws_eks_cluster.this.name
  depends_on = [aws_eks_cluster.this]
}