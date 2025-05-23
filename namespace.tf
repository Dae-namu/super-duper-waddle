# istio-system 네임스페이스 생성
resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

# Karpenter 네임스페이스 생성
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}
