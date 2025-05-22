resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = "istio-system"
  version    = "0.71.3"

  set {
    name  = "collector.enabled"
    value = "true"
  }

  set {
    name  = "query.enabled"
    value = "true"
  }

  set {
    name  = "agent.enabled"
    value = "false"
  }

  set {
    name  = "storage.type"
    value = "memory"
  }

  set {
    name  = "cassandra.enabled"
    value = "false"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
