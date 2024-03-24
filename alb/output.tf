output "tg" {
    value = var.create_target_group ? aws_lb_target_group.alb_tg : null
    description = "The target group info"
}

output "lb" {
    value = var.create_alb ? aws_lb.alb : null
    description = "The load balancer info"
}

output "listener" {
    value = var.create_alb ? aws_lb_listener.listener : null
    description = "The listener info"
}

output "dns_name" {
    value = var.create_alb ? aws_lb.alb.dns_name : null
    description = "The DNS name of the load balancer"
}

output "zone_id" {
    value = var.create_alb ? aws_lb.alb.zone_id : null
    description = "The zone id of the load balancer"
}
