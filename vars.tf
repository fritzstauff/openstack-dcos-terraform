variable "dcos_cluster_name" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "openstack-dcos"
}

variable "openstack_image_id" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "f6fd5761-12b6-4f9b-95e2-9f8be4d186f2"
}

variable "openstack_flavor_id" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "4"
}

variable "openstack_network_name" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "atest1"
}

variable "dcos_master_count" {
  default     = "3"
  description = "Number of master nodes. 1, 3, or 5."
}

variable "dcos_agent_count" {
  description = "Number of agents to deploy"
  default     = "1"
}

variable "dcos_public_agent_count" {
  description = "Number of public agents to deploy"
  default     = "1"
}

variable "dcos_ssh_public_key_path" {
  description = "Path to your public SSH key path"
  default     = "./os-key.pub"
}

variable "dcos_installer_url" {
  description = "Path to get DCOS"
  default     = "https://downloads.dcos.io/dcos/EarlyAccess/dcos_generate_config.sh"
}

variable "dcos_ssh_key_path" {
  description = "Path to your private SSH key for the project"
  default     = "./os-key"
}
