output "tg" {
    value = var.create_target_group ? aws_lb_target_group.alb_tg[0] : null
    description = "The target group info"
}

output "lb" {
    value = var.create_alb ? aws_lb.alb[0] : null
    description = "The load balancer info"
}

output "http_listener" {
    value = (var.create_alb && !var.disable_http) ? aws_lb_listener.http[0] : null
    description = "The http listener info"
}

output "https_listener" {
    value = (var.create_alb && var.enable_https) ? aws_lb_listener.https[0]: null
    description = "The https listner info"
}

output "dns_name" {
    value = var.create_alb ? aws_lb.alb[0].dns_name : null
    description = "The DNS name of the load balancer"
}

output "zone_id" {
    value = var.create_alb ? aws_lb.alb[0].zone_id : null
    description = "The zone id of the load balancer"
}
