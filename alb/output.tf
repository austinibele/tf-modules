output "tg" {
    value = var.create_target_group ? aws_lb_target_group.alb_tg : null
    description = "The target group info"
}

output "lb" {
    value = aws_lb.alb
    description = "The load balancer info"
}

output "listener" {
    value = aws_lb_listener.listener
    description = "The listener info"
}

output "dns_name" {
    value = aws_lb.alb.dns_name
    description = "The DNS name of the load balancer"
}

output "zone_id" {
    value = aws_lb.alb.zone_id
    description = "The zone id of the load balancer"
}
