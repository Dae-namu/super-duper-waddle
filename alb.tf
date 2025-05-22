# Nginx 애플리케이션 배포 (Pod 생성)
resource "kubernetes_deployment" "nginx" {
  depends_on = [
    aws_eks_node_group.this # EC2 노드 그룹이 준비되어야 Pod가 뜰 수 있음
    # aws_eks_fargate_profile.default, # Fargate를 사용한다면 이 의존성도 추가
  ]
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Nginx Pod를 접근할 수 있는 Kubernetes Service (NodePort 타입)
resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-service"
    labels = {
      app = "nginx"
    }
  }

  # app = nginx로 Deployment와 연결
  spec {
    selector = {
      app = "nginx"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# ALB controller를 통해 외부 요청을 Nginx로 라우팅 (ingress 리소스)
resource "kubernetes_ingress_v1" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
    annotations = {
      "kubernetes.io/ingress.class"                         = "alb"
      "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"               = "ip"
      "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path"          = "/"
      "alb.ingress.kubernetes.io/success-codes"             = "200"
      "alb.ingress.kubernetes.io/backend-protocol"          = "HTTP"
      "alb.ingress.kubernetes.io/load-balancer-attributes"  = "idle_timeout.timeout_seconds=600"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = kubernetes_service.nginx.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.nginx
  ]
}
