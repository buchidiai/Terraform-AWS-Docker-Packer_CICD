output "albs_dns_name" {
	value = aws_lb.ec2-grp.dns_name
	description = "The domain name of the load balancer"
}