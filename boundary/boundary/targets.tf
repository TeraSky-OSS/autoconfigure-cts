resource "boundary_target" "redis" {
  type                     = "tcp"
  name                     = "redis"
  description              = "Redis container"
  scope_id                 = boundary_scope.dba_support.id
  session_connection_limit = -1
  session_max_seconds      = 10000
  default_port             = 6379
  host_set_ids = [
    boundary_host_set.redis_containers.id
  ]
}

resource "boundary_target" "postgres" {
  type                     = "tcp"
  name                     = "postgres"
  description              = "Postgres server"
  scope_id                 = boundary_scope.dba_support.id
  session_connection_limit = -1
  session_max_seconds      = 10000
  default_port             = 5432
  host_set_ids = [
    boundary_host_set.postgres_containers.id
  ]
}
