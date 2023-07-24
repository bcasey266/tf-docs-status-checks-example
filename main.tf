# Main

resource "random_pet" "name" {
  length = var.length
}

resource "random_pet" "example" {
  length = var.length
}
