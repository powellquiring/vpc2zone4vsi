variable "ibmcloud_api_key" {}
variable "basename" {}
variable "ssh_key_name" {}
variable "resource_group_name" {}
variable "region" {}

variable "subnets" {
  default = 2
}
variable "profile" {
  default = "cx2-2x4"
}
variable "image_name" {
  default = "ibm-ubuntu-20-04-minimal-amd64-2"
}
