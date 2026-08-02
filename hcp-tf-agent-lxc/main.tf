resource "proxmox_virtual_environment_download_file" "ubuntu_lxc_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.node_name

  url = "http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

resource "proxmox_virtual_environment_container" "tfc_agent" {
  description = "HCP Terraform Agent LXC Container"
  node_name   = var.node_name
  vm_id       = var.vm_id
  unprivileged = true

  initialization {
    hostname = "tfc-agent-lxc"

    ip_config {
      ipv4 {
        address = var.lxc_ip
        gateway = var.lxc_gateway
      }
    }

    dns {
      servers = [var.lxc_dns]
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
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_lxc_template.id
    type             = "ubuntu"
  }

  features {
    nesting = true
  }
}

# HA Resource Configuration for the Agent
resource "proxmox_virtual_environment_haresource" "tfc_agent_ha" {
  depends_on = [proxmox_virtual_environment_container.tfc_agent]

  resource_id = "ct:${var.vm_id}"
  state       = "started"
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
      
      "echo '=== 1. Wait for DNS and Network ==='",
      "for i in {1..30}; do if ping -c 1 download.docker.com &> /dev/null; then break; fi; echo 'Waiting for network...'; sleep 2; done",

      "echo '=== 2. Install Docker ==='",
      "if ! command -v docker &> /dev/null; then",
      "  apt-get update",
      "  apt-get install -y ca-certificates curl gnupg lsb-release",
      "  install -m 0755 -d /etc/apt/keyrings",
      "  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes",
      "  chmod a+r /etc/apt/keyrings/docker.gpg",
      "  echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "  apt-get update",
      "  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "fi",
      
      "echo '=== 3. Run HCP Terraform Agent ==='",
      "docker stop tfc-agent || true",
      "docker rm tfc-agent || true",
      "docker run -d --name tfc-agent --restart unless-stopped --platform=linux/amd64 -e TFC_AGENT_TOKEN=\"$TFC_AGENT_TOKEN\" -e TFC_AGENT_NAME=\"$TFC_AGENT_NAME\" hashicorp/tfc-agent:latest"
    ]
  }
}
