# Core deployment settings
variable "location" {
  type        = string
  description = "Azure region where the AKS platform resources will be deployed."
  default     = "westus2"
}

variable "environment" {
  type        = string
  description = "Short environment name used in resource naming, AKS node pool naming, and tagging. Supported values are dev, qa, and prod."
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of dev, qa, or prod."
  }
}

variable "organization_name" {
  type        = string
  description = "Short organization or team identifier used in resource naming."
  default     = "vp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.organization_name))
    error_message = "organization_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Pinned AKS Kubernetes version for the control plane and node pools."
  default     = "1.34.3"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "kubernetes_version must be a valid Kubernetes version such as 1.34 or 1.34.3."
  }
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional Azure tags to merge with the module defaults."
  default     = {}
}

# Cluster access settings
variable "aks_admin_user_principal_name" {
  type        = string
  description = "Microsoft Entra user principal name to add to the AKS admin group."
  default     = "admin@MngEnvMCAP797847.onmicrosoft.com"
}

variable "ssh_public_key" {
  type        = string
  description = "Relative path to the SSH public key used for Linux node access."
  # Commented as we are using devops pipeline to manage secrets. If you want to use local state, uncomment the default value and ensure the public key file exists at the specified path.
  # default = "aks-prod-sshkeys-terraform/aksprodsshkey.pub"

  validation {
    condition     = fileexists(var.ssh_public_key)
    error_message = "ssh_public_key must point to an existing public key file."
  }
}

variable "linux_admin_username" {
  type        = string
  description = "Linux administrator username for AKS Linux nodes."
  default     = "ubuntu"
}

variable "windows_admin_username" {
  type        = string
  description = "Windows administrator username for AKS Windows nodes."
  default     = "azureuser"
}

variable "windows_admin_password" {
  type        = string
  description = "Windows administrator password for AKS Windows nodes. Supply this through tfvars or environment variables."
  sensitive   = true
  default     = "Password@4124567980" # Placeholder value; override in production with secure password management.
  nullable    = false

  validation {
    condition     = length(var.windows_admin_password) >= 14 && length(var.windows_admin_password) <= 123
    error_message = "windows_admin_password must be between 14 and 123 characters to satisfy AKS Windows node requirements."
  }
}

# Monitoring settings
variable "log_analytics_retention_days" {
  type        = number
  description = "Retention period for the Log Analytics workspace."
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730 days."
  }
}

# Networking settings
variable "aks_vnet_address_space" {
  type        = list(string)
  description = "Address space assigned to the custom virtual network hosting the AKS node pools."
  default     = ["10.240.0.0/16"]

  validation {
    condition     = alltrue([for prefix in var.aks_vnet_address_space : can(cidrnetmask(prefix))])
    error_message = "aks_vnet_address_space must contain valid CIDR ranges."
  }
}

variable "system_node_pool_subnet_address_prefixes" {
  type        = list(string)
  description = "Subnet CIDR ranges for the AKS system node pool."
  default     = ["10.240.0.0/22"]

  validation {
    condition     = alltrue([for prefix in var.system_node_pool_subnet_address_prefixes : can(cidrnetmask(prefix))])
    error_message = "system_node_pool_subnet_address_prefixes must contain valid CIDR ranges."
  }
}

variable "linux_user_node_pool_subnet_address_prefixes" {
  type        = list(string)
  description = "Subnet CIDR ranges for the AKS Linux user node pool."
  default     = ["10.240.4.0/22"]

  validation {
    condition     = alltrue([for prefix in var.linux_user_node_pool_subnet_address_prefixes : can(cidrnetmask(prefix))])
    error_message = "linux_user_node_pool_subnet_address_prefixes must contain valid CIDR ranges."
  }
}

variable "windows_user_node_pool_subnet_address_prefixes" {
  type        = list(string)
  description = "Subnet CIDR ranges for the AKS Windows user node pool."
  default     = ["10.240.8.0/22"]

  validation {
    condition     = alltrue([for prefix in var.windows_user_node_pool_subnet_address_prefixes : can(cidrnetmask(prefix))])
    error_message = "windows_user_node_pool_subnet_address_prefixes must contain valid CIDR ranges."
  }
}

variable "aks_service_cidr" {
  type        = string
  description = "Kubernetes service CIDR used by the AKS cluster. This must not overlap with the VNet address space."
  default     = "10.2.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.aks_service_cidr))
    error_message = "aks_service_cidr must be a valid CIDR range."
  }
}

variable "aks_dns_service_ip" {
  type        = string
  description = "Cluster DNS service IP allocated from aks_service_cidr."
  default     = "10.2.0.10"
}

# Node pool settings
variable "system_node_pool_vm_size" {
  type        = string
  description = "Virtual machine size for the AKS system node pool."
  default     = "Standard_D2_v2"
}

variable "create_linux_user_node_pool" {
  type        = bool
  description = "Set to true to create the dedicated Linux user node pool and subnet."
  default     = false
}

variable "linux_user_node_pool_vm_size" {
  type        = string
  description = "Virtual machine size for the Linux user node pool. Use a Premium SSD-capable SKU for stateful workloads such as MySQL."
  default     = "Standard_DS2_v2"
}

variable "create_windows_user_node_pool" {
  type        = bool
  description = "Set to true to create the dedicated Windows user node pool and subnet."
  default     = false
}

variable "windows_user_node_pool_vm_size" {
  type        = string
  description = "Virtual machine size for the Windows user node pool."
  default     = "Standard_D2_v2"
}

variable "system_node_pool_zones" {
  type        = list(string)
  description = "Availability zones for the AKS system node pool."
  default     = ["3"]
}

variable "user_node_pool_zones" {
  type        = list(string)
  description = "Availability zones for the AKS user node pools."
  default     = ["3"]
}
