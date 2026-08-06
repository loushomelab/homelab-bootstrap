terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "loushomelab"
    workspaces {
      name = "homelab-bootstrap"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
}

provider "proxmox" {
  insecure = true
}
