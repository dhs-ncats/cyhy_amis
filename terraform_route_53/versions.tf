terraform {
  # We want to hold off on 0.13 until we have tested it.
  required_version = "~> 0.12.0"

  # Pin to the latest 2.x AWS provider, since the 3.x provider is
  # unstable and causing problems.
  required_providers {
    aws = "~> 3.0"
  }
}
