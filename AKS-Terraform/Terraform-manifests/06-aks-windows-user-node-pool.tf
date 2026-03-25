# # Dedicated Windows user node pool for Windows application workloads.
# resource "azurerm_kubernetes_cluster_node_pool" "windows_user" {
#   name                        = local.windows_user_node_pool_name
#   kubernetes_cluster_id       = azurerm_kubernetes_cluster.aks.id
#   vm_size                     = var.windows_user_node_pool_vm_size
#   node_count                  = 1
#   min_count                   = 1
#   max_count                   = 3
#   mode                        = "User"
#   os_type                     = "Windows"
#   os_sku                      = "Windows2022"
#   os_disk_size_gb             = 50
#   priority                    = "Regular"
#   orchestrator_version        = var.kubernetes_version
#   auto_scaling_enabled        = true
#   zones                       = var.user_node_pool_zones
#   vnet_subnet_id              = azurerm_subnet.windows_user_node_pool.id
#   temporary_name_for_rotation = local.windows_user_node_pool_rotation_name
#   node_labels                 = local.windows_user_node_pool_labels
#   tags                        = local.windows_user_node_pool_tags

#   upgrade_settings {
#     max_surge                     = "10%"
#     drain_timeout_in_minutes      = 0
#     node_soak_duration_in_minutes = 0
#   }

#   lifecycle {
#     ignore_changes = [
#       node_count,
#     ]
#   }
# }
