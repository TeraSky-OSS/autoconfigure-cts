variable "boundary_addr" {
  default = "http://0.0.0.0:9200"
}

module "kubernetes" {
  source = "./kubernetes"
}

module "boundary" {
  source = "./boundary"
  addr   = var.boundary_addr
}