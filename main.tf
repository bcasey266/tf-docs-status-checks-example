# Main

resource "random_pet" "name" {
  length = var.length
}

resource "random_pet" "name2" {
  length = var.length
}
