resource "null_resource" "test"{
  provisioner "local-exec" {
    command = "echo '0' > status.txt"
  }
  provisioner "local-exec" {
    when = destroy
    command = "echo '1add ' > status.txt"
  }
}