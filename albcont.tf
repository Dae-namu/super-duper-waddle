# helm_alb_controller.tf
resource "helm_release" "aws_load_balancer_controller" {
    depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.this,
    kubernetes_service_account.alb_sa
  ]
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.1"

# ALB Controller가 사용할 EKS 클러스터 이름
  set {
    name  = "clusterName"
    value = local.cluster_name
  }


# ALB Controller가 동작할 VPC의 ID
  set {
    name  = "vpcId"
    value = aws_vpc.this.id
  }

# 서비스 어카운트를 Helm차트에서 생성하지 않도록 설정 (Terraform에서 미리 생성함)
  set {
    name  = "serviceAccount.create"
    value = "false"
  }

# 사용할 서비스 어카운트 이름 명시
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# ALB Controller가 사용할 Kuvernetes서비스 어카운트 생성
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa_role.arn
    }
  }
}

