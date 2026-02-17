variable "location" {
  description = "azure location to deploy resources"
  type        = string
}

variable "customer" {
  description = "Customer name, used for naming of resources"
  type        = string
}

variable "web_admin_username" {
  description = "Admin username for the web VMSS"
  type        = string
  default     = "snapvideoadmin"
}

variable "backend_admin_username" {
  description = "Admin username for the backend Linux VM"
  type        = string
  default     = "snapvideoadmin"
}

variable "backend_ssh_public_key" {
  description = "SSH public key for the backend Linux VM admin user"
  type        = string
}