To enable debug logging for terraform commands :
- export environnement variable TF_LOG : `export TF_LOG=DEBUG` , we can use other levels like TRACE
- execute terraform command

State file are stored locally by default

TF backup my last state file after successful tf apply 

Remote state storage mecanism : we can store the state remotly (aws s3, google storage,  etc)  =>  Allows sharing state file between distributed teams, Allows locking state so parallel executions don't coincide, Enables sharing "output" values with other Terraform configuration or code  

### Terraform concepts
The Terraform backend determines where Terraform state files are stored.
```
terraform {
 backend "s3" {
   region = "us-east-1"
   key = "terraform.tfstate" 
   bucket = "my-bucket"
 }
}
```

Provider with empty configuration: `provider "docker" {}` : 
* the source is not explicitly specified here so, Terraform assumes: registry.terraform.io/hashicorp/docker
* This default only works because docker is a HashiCorp-maintained provider.
* For non-HashiCorp providers, you must specify the source explicitly.

#### Validation bloc
```
variable "external_port" {
  type = number
  default = 8080
  validation {
    condition     = can(regex("8080|80", var.externa_port))
    error_message = "Port values can only be 8080 or 80" 
   }
}
```

we can pass the variable like this (there are other ways of passing variables):
`terraform apply -var external_port=8080
`

#### Terraform modules
- A module is a container for multiple resources that are used together
- The main purpose of modules is to make code reusable elsewhere
- Directory that holds my main terraform code called the **_root module_**
- modules are referenced using a module block
- modules cn be downloaded or referenced from: terraform public registry, a private registry, my local system
- inside module, we can use this reserved parameter:  count, for_each, providers, depends_on
```
module "my_vpc_module" {
  #source is mandatory
  source  = "./modules/vpc"
  version = "0.1"
  region  = var.region
}
```

How to access module outputs in my code?
```
resource "aws_instance" "my_vpc_resource" {
  subnet_id = module.my_vpc_module.subnet_id
}
```

### **Terraform commands**
`terrafrom destory` : destroy **only** resources that exists in the state file , so if we remove a resource from the state file(using terraform state rm or manually) then execute destroy command, the resource still exist

`terraform state list` :  list all resources that terraform is tracking

`terraform state show <resource-name>` : to see details of a specific resource

