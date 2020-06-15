provider "aws"{
region = "ap-south-1"
profile = "First_Task"
}

//Creating Private key

resource "tls_private_key" "SSH_key" {    
  algorithm = "RSA"
}

resource "local_file" "SSH_privatekey" {
    content     = tls_private_key.SSH_key.private_key_pem
    filename = "First_task_key.pem"
    file_permission = 0400                             
}


resource "aws_key_pair" "SSH_key"{            
	key_name= "First_task_key"
	public_key = tls_private_key.SSH_key.public_key_openssh
}

//Creating Security Group 

resource "aws_security_group" "First_task_sg" {
  name        = "First_task_sg"
  description = "Allow SSH AND HTTP for webhosting"


  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "First_task_sg"
  }
}


//Creating Instance


resource "aws_instance" "Firsttaskin" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.SSH_key.key_name
  security_groups = [ aws_security_group.First_task_sg.name ]
   
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Priyanshu Sharma/Desktop/terra/final/First_task_key.pem")
    host     = aws_instance.Firsttaskin.public_ip
  }

  provisioner "remote-exec" {
    inline = [  
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "First_task_os"
  }

}
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.Firsttaskin.availability_zone
  size              = 1
  tags = {
    Name = "First_task_ebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.Firsttaskin.id}"
  force_detach = true
}


output "os_ip" {
  value = aws_instance.Firsttaskin.public_ip
}
resource "aws_s3_bucket" "FirstTask_TerraformS3" {
  
  acl    = "public-read"
  versioning {
enabled=true
}
}


//creating S3 bucket_object

resource "aws_s3_bucket_object" "Tera_bucket" {
  bucket = aws_s3_bucket.FirstTask_TerraformS3.bucket
  key    = "First_task_img"
  acl = "public-read"
  source="C:/Users/Priyanshu Sharma/Desktop/no.jpg"
  etag = filemd5("C:/Users/Priyanshu Sharma/Desktop/no.jpg")
}

// creating cloudfront for s3 bucket

resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [
   null_resource.nullremote3,
  ]
  origin {
    domain_name = aws_s3_bucket.FirstTask_TerraformS3.bucket_regional_domain_name
    origin_id   = "my_first_origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "TERRAFORM_IMAGE_IN_CF"
  default_root_object = "First_task_img"
    default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_first_origin"
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

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
connection {
        type    = "ssh"
        user    = "ec2-user"
        private_key = file("C:/Users/Priyanshu Sharma/Desktop/terra/final/First_task_key.pem")
	host     = aws_instance.Firsttaskin.public_ip
    }
provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/index.html \n \"EOF\""
            "sudo su << EOF",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.Tera_bucket.key}' height='400px' width='400px'></center>\" >> /var/www/html/index.html",
            "EOF"
        ]
    }

}

//connect to instance and format,mount,download github code

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Priyanshu Sharma/Desktop/terra/final/First_task_key.pem")
    host     = aws_instance.Firsttaskin.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Iyan521/Terraform_task1.git /var/www/html/",
    ]
  }
}

//launching chrome as soon as infrastructure is created

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,aws_cloudfront_distribution.s3_distribution
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.Firsttaskin.public_ip}"
  	}
}
