## Did you intend to use gavinbunney/kubectl? If so, you must specify that source address in each module which requires that provider.
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

# Apply a Kubernetes manifest file for external-secrets-store
resource "kubectl_manifest" "external-secrets-store" {
  yaml_body = replace(templatefile("${path.module}/configs/external-secrets.tftpl", var.starburst_helm_values), var.match_empty_line, "")
}

# Apply a Kubernetes manifest file for external-secrets
resource "kubectl_manifest" "external-secrets" {
  yaml_body = replace(templatefile("${path.module}/configs/edpq-secrets.tftpl", var.starburst_helm_values), var.match_empty_line, "")
}

## Helm upgrade starburst
resource "helm_release" "starburst-release" {
  name                = "starburst"
  namespace           = "starburst-live"
  repository          = "https://harbor.starburstdata.net/chartrepo/starburstdata"
  repository_username = var.starburstdata_user
  repository_password = var.starburstdata_pwd
  chart               = "starburst-enterprise"
  version             = "429.0"
  timeout             = var.timeout
  values = [
    replace(templatefile("${path.module}/configs/starburst.tftpl", local.starburst_merged_helm_values), var.match_empty_line, "")
  ]
  set {
    name  = "serviceAccountName"
    value = "starburst-live"
  }
  depends_on = [
    kubectl_manifest.external-secrets
  ]
}

## Helm upgrade cache
resource "helm_release" "cache-release" {
  name                = "cache"
  namespace           = "starburst-live"
  repository          = "https://harbor.starburstdata.net/chartrepo/starburstdata"
  repository_username = var.starburstdata_user
  repository_password = var.starburstdata_pwd
  chart               = "starburst-cache-service"
  version             = "429.0"
  timeout             = var.timeout
  values = [
    replace(templatefile("${path.module}/configs/cache.tftpl", local.starburst_merged_helm_values), var.match_empty_line, "")
  ]
  set {
    name  = "database.external.password"
    value = local.postgres_password
  }
  set {
    name  = "serviceAccountName"
    value = "starburst-live"
  }
  depends_on = [
    helm_release.starburst-release
  ]
}

## Helm upgrade ranger
resource "helm_release" "ranger-release" {
  name                = "ranger"
  namespace           = "starburst-live"
  repository          = "https://harbor.starburstdata.net/chartrepo/starburstdata"
  repository_username = var.starburstdata_user
  repository_password = var.starburstdata_pwd
  chart               = "starburst-ranger"
  version             = "429.0"
  timeout             = var.timeout
  values = [
    replace(templatefile("${path.module}/configs/ranger.tftpl", local.starburst_merged_helm_values), var.match_empty_line, "")
  ]
  set {
    name  = "serviceAccountName"
    value = "starburst-live"
  }
  set {
    name  = "datasources[0].password"
    value = local.ranger_admin_password
  }
  depends_on = [
    helm_release.cache-release
  ]
}
