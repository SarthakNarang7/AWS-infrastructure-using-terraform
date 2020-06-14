provider "aws" {
  region = "ap-south-1"
  profile="mysarthak"
}


resource "aws_security_group" "allow_tls" {
name = "allow_tls"
description = "allow ssh and httpd"

ingress {
description = "SSH Port"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "HTTPD Port"
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "Localhost"
from_port = 8080
to_port = 8080
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "allow_tls"
}
}


variable "enter_ur_key_name" {
type = string
default = "mynewkey"
}

resource "aws_instance" "myinstance" {
ami = "ami-005956c5f0f757d37"
instance_type = "t2.micro"
key_name = var.enter_ur_key_name
security_groups = ["${aws_security_group.allow_tls.name}"]

connection {
type = "ssh"
user = "ec2-user"
private_key = file("C:/Users/HP PAVILION/Desktop/aws/mynewkey.pem")
host = aws_instance.myinstance.public_ip
}
provisioner "remote-exec" {
inline = [
"sudo yum install httpd php git -y",
"sudo systemctl restart httpd",
"sudo systemctl enable httpd",
]
}
tags = {
Name = "SarthakOs"
}
}
output "myaz" {
value = aws_instance.myinstance.availability_zone
}
output "my_sec_public_ip" {
value = aws_instance.myinstance.public_ip
}
resource "aws_ebs_volume" "esb2" {
availability_zone = aws_instance.myinstance.availability_zone
size = 1
tags = {
Name = "myebs1"
}
}
resource "aws_volume_attachment" "ebs_att" {
device_name = "/dev/sdh"
volume_id = aws_ebs_volume.esb2.id
instance_id = aws_instance.myinstance.id
force_detach = true
}
output "myoutputebs" {
value = aws_ebs_volume.esb2.id
}


resource "null_resource"  "myresource"{
depends_on=[ 
aws_volume_attachment.ebs_att,
]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key= file("C:/Users/HP PAVILION/Desktop/aws/mynewkey.pem")
    host     = aws_instance.myinstance.public_ip
  }
 provisioner "remote-exec" {
    inline = [
     "sudo mkfs.ext4 /dev/xvdh",
     "sudo  mount /dev/xvdh /var/www/html",
     "sudo rm -rf /var/www/html/*",
     "sudo git clone https://github.com/SarthakNarang7/AWS-infrastructure-using-terraform.git /var/www/html/", 
      "sudo su <<EOF",
      "echo \"${aws_cloudfront_distribution.s3-web-distribution.domain_name}\" >> /var/www/html/mydesti.txt",
      "EOF",
      "sudo systemctl restart httpd"
    ]
  }
}


resource "aws_s3_bucket" "mybucket" {
  bucket = "my-tf-test-bucketskng"
  acl    = "public-read"

  tags = {
    Name        = "My buckettask1"
    Environment = "Dev"
  }
}

resource "null_resource" "cloning" {
depends_on=[ aws_s3_bucket.mybucket]
  provisioner "local-exec" {
    command = "git clone https://github.com/SarthakNarang7/AWS-infrastructure-using-terraform.git myimage"
  }
}


resource "aws_s3_bucket_object" "web-object1" {
  bucket = aws_s3_bucket.mybucket.bucket
  key    = "hybrid.jpg"
  source = "myimage/hybrid.jpg"
  acl    = "public-read"
  depends_on= [aws_s3_bucket.mybucket,null_resource.cloning]
}


resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.mybucket.id

    custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
  }

   default_root_object = "index.html"
    enabled = true
    
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.html"
    }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.mybucket.id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }


  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.mybucket
  ]
}

resource  "null_resource"  "myresource1"{
depends_on=[
            null_resource.myresource,
            aws_cloudfront_distribution.s3-web-distribution

]
provisioner "local-exec" {
    command = "start chrome ${aws_instance.myinstance.public_ip}"
  }
}
