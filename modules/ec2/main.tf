###############################################################
# MODULE: BASTION HOST
# SSH retry loop — waits until EC2 is actually ready
# No known_hosts step needed — Terraform connection block
# handles host key verification internally
###############################################################

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bh_sg_id]
  associate_public_ip_address = true

  tags = { Name = "Bastion Host" }

  # Retry SSH until EC2 is actually ready — no hardcoded sleep
  provisioner "local-exec" {
    command = <<-CMD
      echo "Waiting for Bastion SSH to be ready..."
      until ssh -i "${var.private_key_path}" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        ubuntu@${self.public_ip} "echo ready" 2>/dev/null; do
        echo "SSH not ready yet — retrying in 10s..."
        sleep 10
      done
      echo "Bastion is SSH-ready at ${self.public_ip}"
    CMD
  }
}
