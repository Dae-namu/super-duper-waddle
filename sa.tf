
# Karpenter 서비스어카운트 생성 및 IAM 역할 ARN 애노테이션 추가 (IRSA용)
resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = kubernetes_namespace.karpenter.metadata[0].name

    # 서비스어카운트에 IAM 역할을 연결하기 위한 애노테이션
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller_role.arn
    }
  }
}
