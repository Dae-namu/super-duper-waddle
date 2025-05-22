# EKS 클러스터용 IAM 역할
resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

## EKS 클러스터를 생성 (EKS 클러스터 IAM 역할 사용)
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }
  depends_on = [ # see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster#example-usage
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

## Fargate에서 팟 배치시 사용하는 실행 역할을 정의
resource "aws_iam_role" "pod_execution" {
  name = "${local.cluster_name}-eks-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "pod_execution_AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.pod_execution.name
}


# 기본적인 Fargate 환경 구성
# EKS 클러스터에 노드를 Fargate로 공급
# 네임스페이스(default, kube-system)에 생성되는 Pod는 Fargate에 의해 실행 (반드시 프라이빗 서브넷만 사용해야 함)
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = local.cluster_name
  fargate_profile_name   = "fp-default"
  depends_on = [ aws_eks_cluster.this ]
  pod_execution_role_arn = aws_iam_role.pod_execution.arn
  subnet_ids             = aws_subnet.private[*].id # 프라이빗 서브넷만 줄 수 있습니다.
  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
}


# EC2기반 node group 구성
resource "aws_iam_role" "node_group" {
  name = "${local.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}


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
  ami_type       = "AL2_x86_64" # Amazon Linux 2

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
}

# EKS 인증 및 Provider연동
# kubernetes provider가 클러스터에 접근할 수 있도록 인증 토큰을 생성
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name # resource "aws_eks_cluster.this"의 이름을 참조
  depends_on = [aws_eks_cluster.this]
}


# ALB Controller를 위한 IRSA구성
resource "aws_iam_role" "alb_sa_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.id
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}



