### Load Balancer
resource "aws_lb" "alb" {
    count              = var.create_alb == true ? 1 : 0
    name               = "${var.project_id}-${var.env}-${var.target_group_suffix}lb"
    internal           = var.internal 
    load_balancer_type = var.load_balancer_type 
    security_groups    = var.security_groups 
    subnets            = var.subnets 
    tags = {
        Environment = var.env
    }
}

resource "aws_lb_listener" "listener" {
    count              = var.create_alb == true ? 1 : 0
    load_balancer_arn = aws_lb.alb[0].arn
    port              = var.enable_https == true ? "443" : "80"
    protocol          = var.enable_https == true ? "HTTPS" : "HTTP"
    default_action {
        type             = "forward"
        target_group_arn = var.target_group 
    }
}


resource "aws_lb_target_group" "alb_tg" {
  count       = var.create_target_group == true ? 1 : 0
  name        = "${var.project_id}-${var.env}-${var.target_group_suffix}-tg"
  port        = var.port
  protocol    = var.protocol
  target_type = var.target_type
  vpc_id      = var.vpc_id
}

# ----------------------------------------------------------
# Listener rules
# ----------------------------------------------------------

resource "aws_lb_listener_rule" "health_check" {
  count              = var.create_alb == true ? 1 : 0
  listener_arn = aws_lb_listener.listener[0].arn

  priority = 1

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "HEALTHY"
      status_code  = "200"
    }
  }

  condition {
    query_string {
      key   = "health"
      value = "check"
    }
  }
}


resource "aws_lb_listener_rule" "require_custom_header" {
  count              = var.create_alb == true ? 1 : 0
  listener_arn = aws_lb_listener.listener[0].arn

  priority = 10

  action {
    type             = "forward"
    target_group_arn = var.target_group
  }

  condition {
    http_header {
      http_header_name = var.custom_header_name
      values           = [var.custom_header_value]
    }
  }
}