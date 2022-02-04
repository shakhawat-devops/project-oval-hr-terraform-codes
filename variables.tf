variable "ami"{
 type = string
  default = "ami-0c1a7f89451184c8b"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "default region"
}

variable "vpc_cidr" {
  type        = string
  default     = "172.16.0.0/16"
  description = "default vpc_cidr_block"
}

variable "pub_sub1_cidr_block"{
   type        = string
   default     = "172.16.1.0/24"
}

variable "prv_sub1_cidr_block"{
   type        = string
   default     = "172.16.2.0/24"
}


variable "sg_ws_name"{
 type = string
 default = "webserver_sg"
}

variable "sg_ws_description"{
 type = string
 default = "SG for web server"
}

variable "sg_ws_tagname"{
 type = string
 default = "SG for web"
}

variable "sg_bs_name"{
 type = string
 default = "bastion_sg"
}


variable "sg_bs_description"{
 type = string
 default = "SG for bastion host"
}

variable "sg_bs_tagname"{
 type = string
 default = "SG for bastion"
}
