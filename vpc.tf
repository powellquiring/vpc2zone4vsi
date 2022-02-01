data "ibm_is_image" "name" {
  name = var.image_name
}

data "ibm_resource_group" "group" {
  name = var.resource_group_name
}

data "ibm_is_ssh_key" "ssh_key" {
  name = var.ssh_key_name
}


locals {
  provider_region = var.region
  name            = var.basename
  tags = [
    "basename:${var.basename}",
    lower(replace("dir:${abspath(path.root)}", "/", "_")),
  ]
  resource_group = data.ibm_resource_group.group.id
  cidr           = "10.0.0.0/8"
  prefixes = { for zone_number in range(3) : zone_number => {
    cidr = cidrsubnet(local.cidr, 8, zone_number)
    zone = "${var.region}-${zone_number + 1}"
  } }
  ssh_key_ids = [data.ibm_is_ssh_key.ssh_key.id]
  image_id    = data.ibm_is_image.name.id
}


resource "ibm_is_vpc" "location" {
  name                      = local.name
  resource_group            = local.resource_group
  address_prefix_management = "manual"
  tags                      = local.tags
}

resource "ibm_is_vpc_address_prefix" "locations" {
  for_each = local.prefixes
  name     = "${local.name}-${each.key}"
  zone     = each.value.zone
  vpc      = ibm_is_vpc.location.id
  cidr     = each.value.cidr
}

resource ibm_is_security_group all {
  name     = "${local.name}-all"
  vpc      = ibm_is_vpc.location.id
  resource_group = data.ibm_resource_group.group.id
}
resource "ibm_is_security_group_rule" "all-outbound" {
  direction = "outbound"
  group = ibm_is_security_group.all.id
}
resource "ibm_is_security_group_rule" "all-inbound" {
  direction = "inbound"
  group = ibm_is_security_group.all.id
}

locals {
  subnets_front = { for zone_number in range(var.subnets) : zone_number => {
    cidr = cidrsubnet(ibm_is_vpc_address_prefix.locations[zone_number].cidr, 8, 0) # need a dependency on address prefix
    zone = local.prefixes[zone_number].zone
  } }
  subnets_back = { for zone_number in range(var.subnets) : zone_number => {
    cidr = cidrsubnet(ibm_is_vpc_address_prefix.locations[zone_number].cidr, 8, 1) # need a dependency on address prefix
    zone = local.prefixes[zone_number].zone
  } }
}

resource "ibm_is_subnet" "front" {
  for_each        = local.subnets_front
  name            = "${var.basename}-front-${each.key}"
  resource_group  = local.resource_group
  vpc             = ibm_is_vpc.location.id
  zone            = each.value.zone
  ipv4_cidr_block = each.value.cidr
  # public_gateway = ibm_is_public_gateway.zone[each.key].id
}

resource "ibm_is_subnet" "back" {
  for_each        = local.subnets_back
  name            = "${var.basename}-back-${each.key}"
  resource_group  = local.resource_group
  vpc             = ibm_is_vpc.location.id
  zone            = each.value.zone
  ipv4_cidr_block = each.value.cidr
  # public_gateway = ibm_is_public_gateway.zone[each.key].id
}


#################### front ################
resource "ibm_is_instance" "front" {
  for_each       = ibm_is_subnet.front
  name           = each.value.name
  vpc            = each.value.vpc
  zone           = each.value.zone
  keys           = local.ssh_key_ids
  image          = local.image_id
  profile        = var.profile
  resource_group = local.resource_group
  primary_network_interface {
    subnet = each.value.id
    security_groups = [ ibm_is_security_group.all.id ]
  }
  tags      = local.tags
}

resource "ibm_is_floating_ip" "front" {
  for_each       = ibm_is_instance.front
  name           = each.value.name
  target         = each.value.primary_network_interface[0].id
  resource_group = local.resource_group
  tags           = local.tags
}

output "instances_front" {
  value = { for key, instance in ibm_is_instance.front : key => {
    name                 = instance.name
    primary_ipv4_address = instance.primary_network_interface[0].primary_ipv4_address
    fip                  = ibm_is_floating_ip.front[key].address
  } }
}


#################### back ################
resource "ibm_is_instance" "back" {
  for_each       = ibm_is_subnet.back
  name           = each.value.name
  vpc            = each.value.vpc
  zone           = each.value.zone
  keys           = local.ssh_key_ids
  image          = local.image_id
  profile        = var.profile
  resource_group = local.resource_group
  primary_network_interface {
    subnet = each.value.id
    security_groups = [ ibm_is_security_group.all.id ]
  }
  tags      = local.tags
}

resource "ibm_is_floating_ip" "back" {
  for_each       = ibm_is_instance.back
  name           = each.value.name
  target         = each.value.primary_network_interface[0].id
  resource_group = local.resource_group
  tags           = local.tags
}

output "instances_back" {
  value = { for key, instance in ibm_is_instance.back : key => {
    name                 = instance.name
    primary_ipv4_address = instance.primary_network_interface[0].primary_ipv4_address
    fip                  = ibm_is_floating_ip.back[key].address
  } }
}
