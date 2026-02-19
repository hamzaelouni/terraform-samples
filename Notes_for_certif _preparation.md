When you initialize a new Terraform workspace, it creates a lock file named **.terraform.lock.hcl** and the **`.terraform directory`**.

providers are the components that Terraform uses to translate the configuration files into API calls for the various services.

Each provider plugin is a binary executable specific to the platform Terraform is running on.

A module in Terraform serves as a container for multiple resources to be used together, allowing for reusability and better organization of your infrastructure code.

Copying the module into the .terraform/modules/downloads directory is not the correct approach for Terraform to find and use the module. Terraform manages module dependencies and downloads them automatically when terraform init is run.

Use modules in your configuration : [https://developer.hashicorp.com/terraform/language/modules/configuration](https://developer.hashicorp.com/terraform/language/modules/configuration)

When you add a module block to your configuration, Terraform does not automatically have that code locally. Running terraform init downloads the module’s source code (along with any providers) into the working directory so it can be used by later commands like plan and apply.

A module is a collection of resources that Terraform manages together.
Every Terraform workspace includes configuration files in its root directory. Terraform refers to this configuration as the root module.
Modules you configure using module blocks are called **`child modules`**.

Terraform can load modules from multiple sources, including the `local file system`, `a Terraform registry`, `and VCS repositories.`
we can configure resources in the root module to reference outputs from the child module.

Modules also have output values, which are defined within the module with the output keyword. You can access them by referring to module.<MODULE NAME>.<OUTPUT NAME>. Like input variables, module outputs are listed under the outputs tab in the Terraform registry.

Module outputs are usually either passed to other parts of your configuration, or defined as outputs in your root module.

In the following example, Terraform selects the module version from a Git repository tagged as v1.2.0:
```
module "vpc" {
source = "git::https://example.com/vpc.git?ref=v1.2.0"
}
```

we can also source a module using its SHA-1 hash:
```
module "storage" {
source = "git::https://example.com/storage.git?ref=51d462976d84fdea54b47d80dcabbf680badcdb8"
}
```

##### Reference module output values
In the following example, the aws_subnet resource references the value of the VCP ID output by the vcp module:
```
module "vcp" {
source  = "terraform-aws-modules/vpc/aws"
version = "6.0.1"
}

resource "aws_subnet" "main" {
vpc_id     = module.vcp.vpc_id
cidr_block = "10.0.1.0/24"

tags = {
Name = "Main"
}
}
```

### Explore the .terraform directory
Terraform uses the .terraform directory to store the project's providers and modules. Terraform will refer to these components when you run validate, plan, and apply.
```
$ tree .terraform -L 1
.terraform
├── environment
├── modules
├── providers
└── terraform.tfstate
```
Notice that the .terraform directory contains three sub-directories and a terraform.tfstate file. The environment file includes the name of your HCP Terraform workspace, and the terraform.tfstate file contains a reference to your workspace's state in HCP Terraform.

The modules and providers directories contain the modules and providers used by your Terraform workspace.


##### Remove a resource from state
To remove a resource from Terraform state without destroying it, replace the resource block with a removed block and then apply the change using the standard Terraform workflow. When you remove a resource from state, Terraform no longer manages that infrastructure's lifecycle.
Add a lifecycle block to the removed block and set the destroy argument to false. Setting destroy to true removes the resource from state and destroys it.
The following example removes the aws_instance.example resource from state but does not destroy it:
```
removed {
from = aws_instance.example

lifecycle {
destroy = false
}
}
```

`terraform destroy` : It deletes the actual, real cloud resources — not just updates the state to remove them

##### Run triggers
Un run trigger sert à forcer Terraform à relancer une action (souvent un provisioner, un script, ou une ressource “one-shot”) même si la ressource elle-même n’a pas changé.
Si la valeur dans triggers change → Terraform détruit puis recrée la ressource → l’action se rejoue.

👉 En clair : « Si cette valeur change, alors je veux que Terraform refasse l’action »

**Le cas typique : null_resource**
```
resource "null_resource" "example" {
triggers = {
    run_trigger = var.version
}

provisioner "local-exec" {
   command = "echo Deploy version ${var.version}"
   }
}
```
Ce qui se passe

* app_version = 1.0 → script exécuté
* Tu passes à 1.1 → Terraform voit que version a changé
* Il recrée la ressource
* Le script se relance


**Rejouer une action quand un fichier change**
```
resource "null_resource" "config" {
   triggers = {
      file_hash = filesha256("nginx.conf")
}

provisioner "local-exec" {
  command = "apply-config.sh"
 }
}
```


**exécuter quelque chose à chaque terraform apply, même sans changement**
```
resource "null_resource" "always_run" {
  triggers = {
     always = timestamp()
}

provisioner "local-exec" {
    command = "echo 'Je m’exécute toujours'"
  }
}
```

Ce qui se passe

* timestamp() change à chaque run
* Terraform recrée la ressource à chaque fois
* L’action est toujours rejouée

**Cas moderne : terraform_data (recommandé) | Même logique, mais plus propre.**
```
resource "terraform_data" "deploy" {
   triggers_replace = {
       version = var.app_version
}

provisioner "local-exec" {
 command = "deploy.sh ${var.app_version}"
  }
}
````


###### **Quand un trigger est-il évalué ?**
⏱️ Le cycle exact

Quand tu fais : terraform apply, Terraform fait en réalité :

1️⃣ Lire l’état (state) actuel

2️⃣ Évaluer la configuration (variables, fonctions, triggers, etc.)

3️⃣ Comparer : valeur actuelle des triggers VS valeur stockée dans le state

4️⃣ Décider :  différent → ressource marquée replace  |  identique → rien à faire

5️⃣ Afficher le plan 

6️⃣ Appliquer (destroy + create si besoin)

👉 Le trigger est donc évalué avant toute action réelle.


##### terraform.lock.hcl
The .terraform.lock.hcl file's primary purpose is to lock the provider versions to ensure that all team members and CI/CD systems use identical versions.
This file should be reviewed and committed to your version control system to synchronize the team's environments.



###### Input variable validation

Use input variable validation to perform the following tasks:

* Verify input variables meet specific format requirements.
* Verify input values fall within acceptable ranges.
* Prevent Terraform operations if a variable is misconfigured.

For example, you can validate whether a variable value has valid AMI ID syntax.
````
variable "image_id" {
type        = string
description = "The id of the machine image (AMI) to use for the server."

validation {
condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
}
}
````

An alias meta-argument is used when using the same provider with different configurations for different resources. This feature allows you to include multiple provider blocks that refer to different configurations. In this example, you would need something like this:
````
provider "aws" {
region  = "us-east-1"
}

provider "aws" {
region = "ap-south-1"
alias  = "mumbai"
}
````
When writing Terraform code to deploy resources, the resources that you want to deploy to the mumbai region would need to specify the alias within the resource block. This instructs Terraform to use the configuration specified in that provider block. So in this case, the resource would be deployed to ap-south-1 region and not the us-east-1 region. This configuration is common when using multiple cloud regions or authentication methods.


###### Use HCP Terraform to create infrastructure

In a CLI-driven workflow with HCP Terraform, plan and apply operations execute remotely on HCP Terraform's infrastructure by default, not on your local machine. This is called remote operations. When you run terraform plan or terraform apply, your configuration files are uploaded to HCP Terraform, the operation runs there, and the output is streamed back to your terminal in real-time. This ensures consistent execution environments, enables better collaboration, and supports features such as policy checks and cost estimation.

---
**`the validation block`** is evaluated during the planning phase to ensure that the specified condition is met before any resource creation is initiated.

---
The terraform `init command` initializes a working directory and downloads any necessary plugins, but it does not evaluate the validation block in variables.

---
The Terraform language is declarative, describing the intended goal rather than the steps to achieve it. The ordering of blocks and the files they are organized into are generally not significant; Terraform only considers implicit and explicit relationships between resources when determining an order of operations.

---
The HCP Terraform private registry allows you to publish and maintain a set of custom modules that are only accessible within your organization. This ensures that your organization's specific modules are securely stored and can only be used by authorized users within your organization.

---

**`Q :`** You have configured a workspace in HCP Terraform (Cloud) to use local execution. In this mode, what does HCP Terraform do? => **`A :`** When using local execution in HCP Terraform, the platform only handles storing and syncing the workspace's state file. This means that you need to run the plan and apply commands locally on your own machine, while HCP Terraform takes care of managing the state file.

---