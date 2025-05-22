# Nginx 애플리케이션 배포 (Pod 생성)
resource "kubernetes_deployment" "nginx" {
    depends_on = [
    aws_eks_node_group.this# EC2 노드 그룹이 준비되어야 Pod가 뜰 수 있음
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


# ALB Controller를 위한 IAM 구성 (IRSA)
resource "aws_iam_policy" "alb_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json") # 이 파일은 공식 문서에 제공된 JSON 내용
}

# 위 정책을 ALB Controller 전용 IAM Role(alb_sa_role)에 부착
resource "aws_iam_role_policy_attachment" "alb_policy_attach" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
  depends_on = [aws_iam_policy.alb_policy, aws_iam_role.alb_sa_role]
}

# OIDC Provider 정의
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  # 여기가 중요합니다: AWS EKS OIDC의 잘 알려진 썸프린트 값을 사용합니다.
  # 이 값은 일반적으로 변하지 않습니다.
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd40f94"]
  depends_on = [aws_eks_cluster.this] # 이제 이 depends_on은 필수는 아니지만, 유지해도 무방합니다.
}


