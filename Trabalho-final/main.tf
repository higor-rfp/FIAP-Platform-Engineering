provider "aws" {
  region = "us-east-1"

  # default_tags: tags de governanca aplicadas a todos os recursos do provider.
  default_tags {
    tags = {
      Project   = "trabalho-final"
      ManagedBy = "terraform"
      Lab       = "01-terraform"
    }
  }
}

module "web-cluster" {
  source = "./modules/web-cluster"
  node_count = lookup({ prod = 3 }, terraform.workspace, 1)
}

