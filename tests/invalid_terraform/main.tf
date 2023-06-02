provider "not-exists" {
}

variable "bad_formating" {
  type = string
  default = "foo"
}

variable "not_exists" {
  type    = ThisTypeDoesntExists
  default = "bar"
}
