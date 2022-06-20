variable "name" {
  type    = string
  default = "auto-onboard"
}
variable "public_subnets" {
  type = list(any)
  default = [
    "10.0.20.0/24",
    "10.0.21.0/24",
    "10.0.22.0/24",
  ]
}
variable "cidr" {
  default = "10.0.0.0/16"
}
variable "instance_types" {
  type = list(string)

}
variable "tags" {
  type = map
}
