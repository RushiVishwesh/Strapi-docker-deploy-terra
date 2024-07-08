provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terra_key_strapi" {
  key_name   = "terra_key_strapi"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "strapi_terra_sg_vishwesh" {
  name        = "strapi_terra_sg_vishwesh"
  description = "strapi_terra_sg_vishwesh"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom Port"
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "strapi_terra_sg_vishwesh"
  }
}

resource "aws_instance" "strapi" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.small"
  key_name      = aws_key_pair.terra_key_strapi.key_name
  security_groups = [aws_security_group.strapi_terra_sg_vishwesh.name]
  
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.example.private_key_pem
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install docker.io -y",
      "sudo usermod -aG docker ubuntu",
      "sudo docker pull vishweshrushi/strapi:latest",
      "sudo docker run -d -p 1337:1337 vishweshrushi/strapi:latest",

      "sudo apt install nginx -y",
      "sudo rm /etc/nginx/sites-available/default",
      "sudo bash -c 'echo \"server {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen 80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen [::]:80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    root /var/www/html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    index index.html index.htm index.nginx-debian.html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    server_name vishweshrushi.contentecho.in;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    location / {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"        proxy_pass http://localhost:1337;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    }\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"}\" >> /etc/nginx/sites-available/default'",
      "sudo systemctl restart nginx"
    ]
  }

  tags = {
    Name = "Strapi-nginx-deploy-vishwesh"
  }
}

resource "aws_route53_record" "vishweshrushi" {
  zone_id = "Z06607023RJWXGXD2ZL6M"
  name    = "vishweshrushi.contentecho.in"
  type    = "A"
  ttl     = 300
  records = [aws_instance.strapi.public_ip]
}

resource "null_resource" "certbot" {
  depends_on = [aws_route53_record.vishweshrushi]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.example.private_key_pem
      host        = aws_instance.strapi.public_ip
    }
    inline = [
      "sudo apt install certbot python3-certbot-nginx -y",
      "sudo certbot --nginx -d vishweshrushi.contentecho.in --non-interactive --agree-tos -m rushivishwesh02@gmail.com"
    ]
  }
}

output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "instance_ip" {
  value = aws_instance.strapi.public_ip
}

output "subdomain_url" {
  value = "http://vishweshrushi.contentecho.in"
}
