output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.subnet.id
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

