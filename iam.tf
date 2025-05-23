# ------------------------------
# EKS 클러스터용 IAM 역할
# ------------------------------
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

# ------------------------------
# Fargate에서 팟 배치시 사용하는 실행 역할
# ------------------------------
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

# ------------------------------
# EC2 기반 Node Group용 IAM 역할
# ------------------------------
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

# ------------------------------
# OIDC Provider 정의 (IRSA용)
# ------------------------------
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd40f94"]
  depends_on      = [aws_eks_cluster.this]
}

# ------------------------------
# ALB Controller를 위한 IAM 구성 (IRSA)
# ------------------------------
resource "aws_iam_policy" "alb_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

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

resource "aws_iam_role_policy_attachment" "alb_policy_attach" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
  depends_on = [aws_iam_policy.alb_policy, aws_iam_role.alb_sa_role]
}

# Karpenter가 사용하는 IAM 정책 정의 (필요 최소 권한)
resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "${local.cluster_name}-KarpenterControllerPolicy"   # 정책 이름에 클러스터 이름 포함
  description = "Karpenter Controller IAM policy"                   # 정책 설명

  # JSON 형식의 IAM 정책 문서
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 인스턴스 및 관련 리소스 생성/관리 권한
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "iam:PassRole",                # IAM 역할을 EC2에 연결할 권한
          "pricing:GetProducts",         # 인스턴스 가격 정보 조회 권한
          "ssm:GetParameter",            # 파라미터 스토어 접근 권한
          "ssm:GetParameters",
          "ec2:DescribeSpotPriceHistory",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # Auto Scaling 그룹 생성 및 관리 권한
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# Karpenter 컨트롤러용 IAM 역할 정의 (IRSA에 연결되는 역할)
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${local.cluster_name}-karpenter-controller"               # 역할 이름

  # 서비스어카운트가 이 역할을 맡을 수 있도록 AssumeRole 정책 작성
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.id             # OIDC 프로바이더를 신뢰
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # IRSA 조건: karpenter 네임스페이스의 karpenter 서비스어카운트만 사용 가능
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
        }
      }
    }]
  })
}

# 위 IAM 정책을 Karpenter 역할에 붙입니다.
resource "aws_iam_role_policy_attachment" "karpenter_policy_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# EC2 노드 그룹용 인스턴스 프로파일 (역할과 연결)
resource "aws_iam_instance_profile" "node_group" {
  name = "${local.cluster_name}-node-group-instance-profile"
  role = aws_iam_role.node_group.name
}
