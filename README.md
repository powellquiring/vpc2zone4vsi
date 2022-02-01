# vpc 2 zone 4 vsi

## Set up
```
cp template.local.env local.env
edit local.env
source local.env
terraform init
terraform apply
```

## Test
Terraform output looks something like this.  Notice the floating IP addresses and `primary_ipv4_address` that are used in the testing example.

Testing example:
```
$ terraform output
instances_back = {
  "0" = {
    "fip" = "150.239.110.125"
    "name" = "bug00-back-0"
    "primary_ipv4_address" = "10.0.1.4"
  }
  "1" = {
    "fip" = "169.59.165.105"
    "name" = "bug00-back-1"
    "primary_ipv4_address" = "10.1.1.4"
  }
}
instances_front = {
  "0" = {
    "fip" = "52.116.120.92"
    "name" = "bug00-front-0"
    "primary_ipv4_address" = "10.0.0.4"
  }
  "1" = {
    "fip" = "169.63.181.140"
    "name" = "bug00-front-1"
    "primary_ipv4_address" = "10.1.0.4"
  }
}

# front0 zone 1, 10.0.0.4
$ ssh root@52.116.120.92
#same zone
ping 10.0.1.4
#diff zone
ping 10.1.0.4
ping 10.1.1.4
```

