resource "kubernetes_manifest" "nginx_gateway" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-gateway"
      namespace = "default"
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [{
        port = {
          number   = 80
          name     = "http"
          protocol = "HTTP"
        }
        hosts = ["*"]
      }]
    }
  }
}

resource "kubernetes_manifest" "nginx_virtualservice" {
  depends_on = [kubernetes_manifest.nginx_gateway]
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "nginx-vs"
      namespace = "default"
    }
    spec = {
      hosts    = ["*"]
      gateways = ["nginx-gateway"]
      http = [{
        match = [{
          uri = {
            prefix = "/"
          }
        }]
        route = [{
          destination = {
            host = "nginx-service.default.svc.cluster.local" # 🔸 서비스 이름 확인 필요
            port = {
              number = 80
            }
          }
        }]
      }]
    }
  }
}
