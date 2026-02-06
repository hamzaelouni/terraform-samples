terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0"
    }
  }
}

# configure docker provider
provider "docker" {}

# image to be used by container
resource "docker_image" "terraform-centos" {
  name = "centos:7"
  keep_locally = true
}

# create a container
resource "docker_container" "centos" {
  image = docker_image.terraform-centos.image_id
  name = "terraform-centos"
  start =  true
  command = ["/bin/sleep","500"]
}