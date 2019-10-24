provider "aws" {
  version = "~> 2.0"
  region  = "ap-southeast-2"
}

resource "aws_ecr_repository" "ecr" {
  name = "varuntest"
}

output "ecr_out" {
  value = "${aws_ecr_repository.ecr}"
}