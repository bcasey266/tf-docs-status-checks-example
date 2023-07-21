# Outputs

output "pet_name" {
  value       = random_pet.name.id
  description = "The randomly generated pet name"
}
