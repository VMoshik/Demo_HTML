provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Security Group for Jenkins and Ansible Instance
resource "aws_security_group" "jenkins_ansible_sg" {
  name        = "jenkins_ansible_security_group"
  description = "Allow SSH, Jenkins"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "JenkinsAnsibleSecurityGroup"
  }
}

# Security Group for Prometheus Instance
resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus_security_group"
  description = "Allow SSH and Prometheus"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
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
    Name = "PrometheusSecurityGroup"
  }
}

resource "aws_instance" "jenkins_ansible" {
  ami           = "ami-04a81a99f5ec58529" 
  instance_type = "t2.medium"              
  key_name      = "NewLap"         

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y ansible
              sudo apt-get install -y openjdk-11-jdk
              wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
              sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
              sudo apt-get update
              sudo apt-get install -y jenkins
              sudo systemctl start jenkins
              sudo systemctl enable jenkins
              EOF

  tags = {
    Name = "Jenkins-Ansible-Instance"
  }

  security_groups = [aws_security_group.jenkins_ansible_sg.name]
}

# Prometheus Instance
resource "aws_instance" "prometheus" {
  ami           = "ami-04a81a99f5ec58529" 
  instance_type = "t2.medium"              
  key_name      = "NewLap"         

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y wget
              wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
              tar xvfz prometheus-2.45.0.linux-amd64.tar.gz
              sudo mv prometheus-2.45.0.linux-amd64 /usr/local/prometheus
              sudo ln -s /usr/local/prometheus/prometheus /usr/local/bin/prometheus
              sudo ln -s /usr/local/prometheus/promtool /usr/local/bin/promtool
              sudo useradd -M -r -s /bin/false prometheus
              sudo mkdir /etc/prometheus
              sudo mkdir /var/lib/prometheus
              sudo chown prometheus:prometheus /var/lib/prometheus
              sudo mv /usr/local/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
              sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
              sudo tee /etc/systemd/system/prometheus.service > /dev/null <<-EOL
              [Unit]
              Description=Prometheus
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=prometheus
              Group=prometheus
              Type=simple
              ExecStart=/usr/local/bin/prometheus \
                --config.file /etc/prometheus/prometheus.yml \
                --storage.tsdb.path /var/lib/prometheus/ \
                --web.console.templates=/usr/local/prometheus/consoles \
                --web.console.libraries=/usr/local/prometheus/console_libraries

              [Install]
              WantedBy=multi-user.target
              EOL
              sudo systemctl daemon-reload
              sudo systemctl start prometheus
              sudo systemctl enable prometheus
              EOF

  tags = {
    Name = "Prometheus-Instance"
  }

  security_groups = [aws_security_group.prometheus_sg.name]
}

output "jenkins_ansible_public_ip" {
  value = aws_instance.jenkins_ansible.public_ip
}

output "prometheus_public_ip" {
  value = aws_instance.prometheus.public_ip
}
