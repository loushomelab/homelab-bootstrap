terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.61.0"
    }
  }
}

provider "proxmox" {
  insecure = true
}

resource "proxmox_virtual_environment_cluster_ha_group" "agent_group" {
  group = "agent-ha"
  nodes = {
    "r720"  = 1
    "1920x" = 2
    "3960x" = 3
  }
}
