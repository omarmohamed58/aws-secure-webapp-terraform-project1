##############################
# Target group (refactored)  #
##############################
resource "aws_lb_target_group" "tg_core" {
  name        = "${var.project_prefix}-${var.target_suffix}"
  port        = var.port_target
  protocol    = var.protocol_target
  vpc_id      = var.vpc
  target_type = "instance"

  health_check {
    path                = var.health_path
    protocol            = var.protocol_target
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(
    var.common_tags,
    { Service = "${var.project_prefix}-${var.target_suffix}" }
  )
}

####################################
# Attach each instance to the TG   #
# using for_each to avoid count    #
####################################
locals {
  attach_map = { for id in var.instance_list : id => id }
}

resource "aws_lb_target_group_attachment" "tg_attach" {
  for_each         = local.attach_map
  target_group_arn = aws_lb_target_group.tg_core.arn
  target_id        = each.key
  port             = var.port_target
}

############################
# Listener (refactored)    #
############################
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_core.arn
  }
}
