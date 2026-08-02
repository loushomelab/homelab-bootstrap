resource "proxmox_virtual_environment_container" "tfc_agent" {
  description = "HCP Terraform Agent LXC Container"
  node_name   = var.node_name
  vm_id       = var.vm_id

  initialization {
    hostname = "tfc-agent-lxc"

    ip_config {
      ipv4 {
        address = var.lxc_ip
        gateway = var.lxc_gateway
      }
    }

    user_account {
      keys     = [var.ssh_public_key]
      password = var.lxc_password
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.datastore_id
    size         = 8
  }

  network_interface {
    name = "eth0"
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "ubuntu"
  }

  features {
    nesting = true
  }
}

# HA Resource Configuration for the Agent
# This tells Proxmox HA manager to manage this LXC
resource "proxmox_virtual_environment_cluster_ha" "tfc_agent_ha" {
  depends_on = [proxmox_virtual_environment_container.tfc_agent]

  resource_id = "ct:${var.vm_id}"
  state       = "started"
  # You can specify a group if you have created one, otherwise it balances across the cluster
  # group = "your-ha-group" 
}

# Use null_resource to deploy Docker and HCP Agent
resource "null_resource" "deploy_tfc_agent" {
  depends_on = [proxmox_virtual_environment_container.tfc_agent]

  triggers = {
    container_id = proxmox_virtual_environment_container.tfc_agent.id
    agent_token  = var.tfc_agent_token
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = var.ssh_private_key
    host        = split("/", var.lxc_ip)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "export TFC_AGENT_TOKEN='${var.tfc_agent_token}'",
      "export TFC_AGENT_NAME='homelab-lxc-docker-agent'",
      
      "echo '=== 1. Install Docker ==='",
      "if ! command -v docker &> /dev/null; then",
      "  apt-get update",
      "  apt-get install -y ca-certificates curl gnupg",
      "  install -m 0755 -d /etc/apt/keyrings",
      "  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes",
      "  chmod a+r /etc/apt/keyrings/docker.gpg",
      "  echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "  apt-get update",
      "  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "fi",
      
      "echo '=== 2. Run HCP Terraform Agent ==='",
      "docker stop tfc-agent || true",
      "docker rm tfc-agent || true",
      "docker run -d --name tfc-agent --restart unless-stopped --platform=linux/amd64 -e TFC_AGENT_TOKEN=\"$TFC_AGENT_TOKEN\" -e TFC_AGENT_NAME=\"$TFC_AGENT_NAME\" hashicorp/tfc-agent:latest"
    ]
  }
}
