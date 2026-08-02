variable "node_name" {
  type        = string
  description = "Initial Proxmox node for the LXC"
  default     = "3960x"
}

variable "vm_id" {
  type    = number
  default = 200
}

variable "tfc_agent_token" {
  description = "HCP Terraform Agent Token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key for remote-exec"
  type        = string
  sensitive   = true
}

variable "lxc_password" {
  description = "LXC Root Password"
  type        = string
  sensitive   = true
}

variable "template_file_id" {
  description = "Proxmox LXC template ID on Ceph-pool"
  type        = string
  default     = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

variable "datastore_id" {
  description = "Proxmox datastore ID"
  type        = string
  default     = "Ceph-pool"
}

variable "lxc_ip" {
  description = "Static IP for LXC (required for remote-exec, e.g., 192.168.50.200/24)"
  type        = string
  default     = "192.168.50.200/24"
}

variable "lxc_gateway" {
  description = "Default gateway for LXC"
  type        = string
  default     = "192.168.50.1"
}
