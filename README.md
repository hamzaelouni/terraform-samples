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

#### Built-In Functions
- Terraform comes pre-packaged with functions to help you transform and combine values.
- User-defined functions **are not allowed** — only built-in ones.

Built-in functions are extremely useful in making Terraform code dynamic and flexible.
```
variable "project-name" {
  type    = string
  default = "prod"
}

resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
        Name = join("-", ["terraform", var.project-name])}  => result is : terraform-prod
}
```

contains(["test", "build", 1,2,3], "build") : return true because build exists in the list

#### Complex Types

1- **Collections**
- Collection types allow multiple values **of one primitive type** to be grouped together
- Constructors for these Collections include:
  *     list(type)
  *     map(type)
  *     set(type)

example :
```
variable "training" {
  type    = list(string)
  default = ["ACG" , "LA" ]
}
```
2- **Structural**

- Structural types allow multiple values of different primitive types to be grouped together
- Constructors for these Collections include:
    *     object(type)
    *     tuple(type)
    *     set(type)

example:
```
variable "instructor" {
  type = object({
    name = string
    age  = number 
  })
}
```


#### Dynamic Types - The 'any' constraint
- `**any**` is a placeholder for a primitive type yet to be decided
- Actual type will be determined at runtime

```
variable "data" {
  type = list(any)
  default = [1, 42, 7]
}
```
**Even if the default value is numeric, the variable can still accept other types.**

### **Dynamic blocks**
- Dynamically constructs repeatable nested configuration blocks inside Terraform resources
- Supported within the following block types: resource, data, provider, provisioner

### Terraform format (fmt)
- Formats Terraform code for readability
- Helps in keeping code consistent
- Safe to run at any time
- 

### **Terraform commands**

`terraform output` command is used to extract the values of output variables from the state file. this command is useful for retrieving output values.

`terrafrom destory` : destroy **only** resources that exists in the state file , so if we remove a resource from the state file(using terraform state rm or manually) then execute destroy command, the resource still exist

`terraform state list` :  list all resources that terraform is tracking

`terraform state show <resource-name>` : to see details of a specific resource

`terraform console` : Terraform console is an interactive REPL used to inspect state values and test Terraform expressions in real time without applying changes.

`terraform fmt` : formats Terraform configuration files (.tf) to follow standard HCL style. 

`terraform fmt -recursive` :  format all subdirectories

`terraform fmt -check` : fail if files are not formatted, it makes no changes to files it just verify if files are well formatted or not

`terraform workspace show` : Check current workspace

`terraform workspace list` : List all workspaces

`terraform workspace new dev `: Create a new workspace

`terraform workspace select staging` : Switch to an existing workspace

`terraform workspace delete old-env` : Delete a workspace (must not be current workspace)

`terraform workspace new prod` : Create and switch in one command

`terraform taint` : forces a resource to be destroyed and recreated on the next apply by marking it as unhealthy in the state. it is deprecated in recent Terraform versions. It only changes the Terraform state file. It simply marks the resource as tainted in the state. Tainting a resource may cause other resources to be modified. Preferred replacement `terraform apply -replace=<resource-name>`

`terraform import <resource_address> <real_resource_id>` : Reads a real, already-existing resource (created manually or by another tool), Maps it to a Terraform resource address, Writes it into terraform.tfstate. No resource is created, modified, or destroyed.

**when to use terraform import :**

* When you need to work with existing resources
* if you are not allowed to create new resources
* When you're not in control of creation process of infrastructure

### Terraform configuration block
The Terraform configuration block is the top-level terraform {} block that defines **how Terraform itself behaves, not your infrastructure.**

**What goes inside the terraform {} block:**

1️⃣ required_version : Controls which Terraform CLI versions are allowed.
2️⃣ required_providers : This is mandatory in Terraform ≥ 0.13.
3️⃣ backend : Configures remote state storage. **_Only one backend per root module._**

**What does NOT go inside**

❌ Resources
❌ Variables
❌ Providers
❌ Outputs

The terraform {} block is used only in the root module because it configures Terraform itself, including providers and backend, which are global to the workspace.

example :
```
terraform {
  required_version = ">= 1.6"

required_providers {
  docker = {
     source  = "kreuzwerker/docker"
     version = "~> 3.0"
   }
}

backend "s3" {
  bucket = "tf-states"
  key    = "docker/terraform.tfstate"
  region = "eu-west-1"
  }
}
```

**Terraform starts with a single workspace that is always called default. It cannot be deleted.**


#### Using Workspaces in Configuration
we can reference the current workspace in your Terraform code using **terraform.workspace**


### Debugging terraform
- TF_LOG is an environment variable for enabling verbose logging in Terraform.
  By default, it will send logs to stderr (standard error output).
- Can be set to the following levels: TRACE, DEBUG, INFO, WARN, ERROR. 
  TRACE is the most verbose level of logging and the most reliable one.
- To persist logged output, use the TF_LOG_PATH environment variable.
- Setting logging environment variables for Terraform on Linux:
  `export TF_LOG=TRACE | 
   export TF_LOG_PATH=. /terraform. log`


### Hashicorp Sentinel - Policy as Code
- **Sentinel runs after plan, before apply.**
- policy-as-code framework used to enforce governance, security, and compliance rules across HashiCorp products—most notably Terraform.
- Enforces policies on your code.
- Has its own policy language - Sentinel language
- Designed to be approachable by non-programmers.
- Key idea: Terraform describes **WHAT you want**. Sentinel decides **WHETHER you’re allowed to do it**.

```
terraform plan
↓
Terraform Cloud generates a plan
↓
Sentinel evaluates policies
↓
PASS → terraform apply allowed
FAIL → terraform apply blocked
```
