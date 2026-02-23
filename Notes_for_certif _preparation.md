1️⃣ Phases of Terraform Execution

1. terraform init

   * Downloads providers, modules, plugins
   * Prepares Terraform environment

2. terraform plan

* Reads all .tf files and variables
* Builds the dependency graph (DAG)
  * Lists all resources and modules
  * Computes their dependencies:
      * Implicit dependencies (from references like aws_vpc.vpc.id)
      * Explicit dependencies (depends_on)
  * Determines the order of operations

3. terraform apply

    * Executes the plan following the DAG
    * Creates, updates, or deletes resources in the correct order

4. terraform destroy (optional)

   * Builds DAG in reverse for safe destruction

---

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
Par défaut, terraform plan compare trois éléments, pas seulement deux.
🔎 Ce que fait vraiment terraform plan
Par défaut, Terraform fait :
1) Cloud réel  →  met à jour le state (refresh)
2) State       →  comparé au code (.tf)

🧠 Décomposition précise

**Étape 1 — Refresh**

Terraform appelle le provider (AWS, Azure, GCP…)
Il récupère l’état réel des ressources.

Exemple :
* EC2 changé manuellement
* Security group modifié
* Tag ajouté dans la console

Il met à jour le state en mémoire.

**Étape 2 — Diff configuration**

Il compare :

`Configuration désirée (.tf)
VS
State mis à jour`

Et génère un plan :
* create
* ~ update
* destroy
* +/- replace


###### ⚠️ Cas spécial : -refresh=false

Si tu fais :
```
terraform plan -refresh=false
```
Alors là, terraform compare uniquement :

`State (existant)  ↔  Configuration (.tf)`
Il ne regarde pas le cloud réel.

#### terraform plan change réellement le state file?
👉 Non. terraform plan ne modifie pas réellement le state file sur disque (ou dans le remote backend).
Quand tu fais : `terraform plan`
Terraform :

1. 🔄 Refresh le state en mémoire
2. 📊 Calcule le diff
3. 🧾 Affiche le plan 
4. ❌ N’écrit rien dans le state persistant

---

##### terraform show vs terraform state show.

The key differences between these commands relate to scope and usage. The terraform show command displays the complete contents of the state file in human-readable format without requiring any arguments, making it ideal for getting a full overview of your infrastructure. In contrast, terraform state show is targeted and requires a specific resource address as an argument, such as terraform state show aws_instance.web, to view details about just that resource.

---
##### TF_VAR_name

Environment variables can be used to set variables. The environment variables must be in the format TF_VAR_name and this will be checked last for a value. For example:
```
export TF_VAR_region=us-west-1
export TF_VAR_ami=ami-049d8641
export TF_VAR_alist='[1,2,3]'
export TF_VAR_amap='{ foo = "bar", baz = "qux" }'
```

---
Using the `-reconfigure` flag with the `terraform init` command allows you to reconfigure the backend without copying the existing state. This is the correct flag to use when changing the backend configuration without transferring the existing state data.

---
Terraform is written in HashiCorp Configuration Language (HCL). However, Terraform also supports a JSON-compatible syntax.

Terraform is primarily designed on `immutable infrastructure principles`

Terraform is also a declarative language: you simply declare the desired state, and Terraform ensures that real-world resources match that state as written. An imperative approach differs, in which the tool uses a step-by-step workflow to achieve the desired state.

---
The `terraform refresh` command reads the current settings from all managed remote objects and updates the Terraform state to match. This command is deprecated. Instead, add the `-refresh-only` flag to terraform apply and terraform plan commands.
This does not modify your real remote objects, but it modifies the Terraform state.

---

Marking a variable as `sensitive = true` in Terraform does not prevent it from being written to the state file. It only ensures that the value is redacted (masquée) in the CLI output and logs, but it will still be stored in the state file.

Marking variables or outputs as sensitive = true only redacts them from CLI/UI output; it does not keep the values out of state.

Therefore, protecting secrets means protecting state: prefer remote backends with encryption at rest, IAM/RBAC, and state locking; restrict who can read state; avoid surfacing secrets in outputs; and minimize where secrets appear in configuration. In short, assume state may contain secrets and treat it as sensitive data that must be encrypted, access-controlled, and audited.

---
`**"Drift"**` in the context of a workspace's state in Terraform refers to the scenario where the actual infrastructure has been modified outside of Terraform, causing it to deviate from the desired state defined in the configuration. This can lead to inconsistencies and potential issues in managing the infrastructure.

---
Terraform uses the state file to improve performance by caching resource attributes. By storing the current state of your infrastructure, Terraform can avoid making unnecessary API calls to retrieve resource information, which helps speed up the execution of Terraform commands.

The state file is necessary to track metadata such as resource dependencies. This information is crucial for Terraform to understand the relationships between different resources and ensure that changes are applied in the correct order.

---

Terraform state is fundamental to how Terraform operates. The state file serves three primary purposes: First, it creates a mapping between your configuration code and real-world resources. When you define an AWS EC2 instance in your .tf file, Terraform records in state which actual EC2 instance (with its specific resource ID) corresponds to that configuration block. Without this mapping, Terraform wouldn't know which resources it manages and which were created by other means.

Second, state tracks metadata that isn't visible in your configuration, such as resource dependencies. Terraform uses this metadata to determine the correct order for creating, updating, or destroying resources; ensuring a VPC exists before creating subnets within it, for example.

Third, state improves performance by caching resource attributes. Instead of querying your cloud provider API for every attribute of every resource during each plan operation, Terraform reads this information from state, making operations significantly faster, especially in large infrastructures. Note that state does NOT handle encryption of configuration files, fix syntax errors, or validate credentials - these are separate Terraform functions handled by other mechanisms.

---
the version argument with module is optional, but it is recommended to ensure consistent and reproducible deployments

---

* `precondition` — runs during the plan phase, before Terraform computes the resource's changes. If it fails, the plan is aborted immediately. It's used to validate inputs/dependencies before attempting any action.
* `postcondition` — runs during the apply phase, after the resource has been created/updated. If it fails, Terraform marks the apply as failed. It's used to assert that the resulting state meets expectations.
* postcondition can reference self to access the resource's resulting attributes; precondition cannot (the resource doesn't exist yet).

---

No, child modules do **not** automatically inherit anything from the root module. Everything must be explicitly passed.

```hcl
# root module
module "child" {
  source = "./modules/child"
  
  env    = var.env      # must explicitly pass
  region = var.region   # must explicitly pass
}
```

```hcl
# child module - must declare the variable
variable "env" {}
variable "region" {}
```

If you don't pass it, the child has no access to it — no implicit inheritance of variables, locals, or outputs from the parent.

**What IS inherited automatically:**

- **Provider configurations** — child modules inherit the provider from the root by default (unless you use `providers` argument to pass explicit aliases).

That's the only implicit inheritance in Terraform.

---

Dans le bloc `module`, tu **passes des valeurs** au module enfant, comme des arguments de fonction.

```hcl
module "child" {
  source = "./modules/child"
  
  env    = var.env       # env   → nom de la variable dans le module enfant
                         # var.env → valeur qui vient du module root
}
```

Donc :
- **à gauche** du `=` → le nom de la `variable` déclarée dans le module enfant
- **à droite** du `=` → la valeur que tu lui donnes (depuis le root)

**Analogie avec une fonction Java :**

```java
// déclaration dans le module enfant
void deploy(String env, String region) { ... }

// appel depuis le root
deploy(env, region);
```

Le module enfant doit avoir déclaré :
```hcl
# modules/child/variables.tf
variable "env" {}
variable "region" {}
```

Et il accède à ces valeurs avec `var.env`, `var.region` dans son propre contexte.

---

No, `locals` are **scoped to the module** where they're defined. Not inherited at all.

```hcl
# root module
locals {
  common_tags = { env = "prod" }
}

module "child" {
  source = "./modules/child"
  # child has NO access to local.common_tags
}
```

If you want the child to use it, you must pass it explicitly as a variable:

```hcl
module "child" {
  source = "./modules/child"
  tags = local.common_tags  # pass it explicitly
}
```

Simple rule: **locals are private to their module**, just like a local variable in a Java method — not visible outside.

---

`HCP Terraform (formerly Terraform Cloud)` is HashiCorp's managed platform for running Terraform — it provides remote state storage, remote plan/apply execution, team collaboration, policy enforcement (Sentinel), and variable management.

Variable scope levels in HCP Terraform, from broadest to narrowest:

1. Variable Sets — define variables once, apply to multiple workspaces:

* Global → applied to all workspaces in the organization
* Project-scoped → applied to all workspaces within a specific project
* Workspace-scoped → applied to selected workspaces manually

2. Workspace variables — defined directly on a specific workspace, override variable sets if conflict.

**_Priority rule_**: workspace-level variable always wins over variable sets if the same key exists in both.

---

When child modules DO need explicit provider — multiple provider aliases:

```hcl
# root/main.tf
provider "aws" {
    alias  = "eu"
    region = "eu-west-1"
}

provider "aws" {
    alias  = "us"
    region = "us-east-1"
}

module "child" {
    source = "./modules/child"
    providers = {
        aws = aws.eu   # ← explicitly pass which alias
}
}
```

---

`moved block` is used to tell Terraform that a resource has been renamed or moved without destroying and recreating it. (Only affects state, no infrastructure changes
)

---

* merge — merge multiple `maps` into one
* concat — merge multiple lists into one (no flattening)
* flatten — nested lists → single flat list
* join — list of strings → single string

---

`-backend-config` is a flag used to pass backend configuration externally at terraform init, instead of hardcoding it in the code.

**Why use it?**
Avoid putting sensitive values (credentials, bucket names) directly in .tf files, or to reuse the same config for different environments.

---

Sentinel — HashiCorp's native policy framework
Policies are evaluated between plan and apply

---

`terraform apply -replace=<address>`
this command is used to force a resource to be destroyed and recreated, even if there are no configuration changes that would require it. This is achieved by specifying the resource address that needs to be replaced, ensuring that the resource is recreated with the latest configuration.

---

The `terraform apply -refresh-only` command is used to update the state file with the latest real-world infrastructure information without making any changes to the resources. It does not force a resource to be destroyed and recreated, even if there are no configuration changes that would require it.

---

Defining the S3 backend in the terraform block and running terraform init is the correct way to configure and initialize the backend for storing state in Amazon S3. This approach ensures that the state is migrated from the local backend to the remote S3 backend.

---

Validation blocks are used for input validation, not for checking the resource's state after creation.

---

The .terraform.lock.hcl file is a dependency lock file that Terraform uses to ensure consistent dependency versions across different runs. It is created or updated every time you run terraform init to initialize the working directory and download the necessary providers and modules.

---

child modules in Terraform do not have access to root variables defined in terraform.tfvars. The child module needs to explicitly receive values through the module block to access specific variables from the root module.

---

Terraform does not scan or discover all resources in the provider account. It refreshes only the resources already in the state file and compares that refreshed state to the configuration.

---

While moved blocks don't need to remain in your configuration permanently, you should keep them for at least one full apply cycle after all team members and automation systems have run terraform apply with the moved block present. Removing a moved block too quickly can cause problems if someone runs Terraform with an old state file that hasn't yet processed the move - Terraform would interpret the old resource address as deleted and the new one as needing to be created. Best practice is to keep moved blocks through a few apply cycles or until you're confident all state files have been updated, then remove them in a future refactoring effort.

---

While Terraform helps manage infrastructure across multiple cloud providers, it still requires provider-specific credentials and authentication flows to interact with each cloud platform. Terraform abstracts away the complexity of managing infrastructure, but it does not eliminate the need for provider-specific authentication.

---

Running `terraform init -upgrade` will download the new module version and update your configuration to use the latest available version. This command is specifically designed to safely upgrade modules in your Terraform configuration.

---

While some remote backends in Terraform support state locking by default, it is not a universal feature. It is crucial to verify the state locking capabilities of the specific remote backend being used and configure state locking settings accordingly to prevent concurrent modifications to the Terraform state.

---

`Describe how to organize and use HCP Terraform workspaces and projects`

HCP Terraform variable sets are groups of reusable variables created at the organization level. A variable set can have one of three scopes:

Global: It will apply to all current and future workspaces within an organization.

Project-specific: It will apply to all current and future workspaces within the selected projects.

Workspace-specific: It will apply only to the selected workspaces.

Using a broader variable set scope enables self-service workflows. For instance, you can create a variable set and apply it to a team-specific project, then grant the team permission to create workspaces within the project. Future workspaces will automatically inherit the variable set without requiring additional work or approval. However, we recommend scoping variable sets that contain credentials as narrowly as possible to avoid granting access to teams or workspaces that do not need them.

---

`run tasks
`
This is the correct choice because HCP Terraform run tasks allow you to integrate external tools into the workflow between the plan and apply phases. This feature lets you run custom scripts or tools to perform additional checks or validations on Terraform plans before applying changes to the infrastructure.

---

Adding a lifecycle block with `create_before_destroy = tru`e ensures that the new database is created before the old one is destroyed. This helps avoid downtime by keeping the database available during the transition.

---

In HCP Terraform, **a workspace can be mapped to only one VCS** (Version Control System) repository. This means that the workspace will be associated with a single repository where the Terraform configuration files are stored and managed.

---

Starting with recent versions of Terraform, import is now part of the standard config-driven workflow using import blocks. When you add an import block to your configuration, running terraform plan will show that Terraform intends to import the existing resource, and terraform apply will actually perform the import operation. This is the modern, declarative approach to importing resources; you declare the import in configuration rather than using the imperative terraform import command.

we need both:
1. A resource block 
2. An import block

```
resource "aws_instance" "vm" {
You must define the resource block
}
```

```
import {
to = aws_instance.vm
id = "i-0abc123456"
}
```

---

version = "~> 3.2.0" : Allow patch updates, but do NOT allow minor or major upgrades.

~> 3.2.0 allows ( >= 3.2.0 and < 3.3.0 ) :

✅ 3.2.0

✅ 3.2.1

✅ 3.2.5

❌ 3.3.0

❌ 4.0.0

---

**Les provisionneurs Terraform**

Les provisionneurs sont utilisés pour exécuter des scripts ou des commandes shell sur une machine locale ou distante dans le cadre de la création/suppression de ressources. Ils sont similaires aux user-data dans une instance EC2 qui ne s'exécutent qu'une seule fois lors de la création. D'ailleurs, Terraforme est même capable de les exécuter en cas d'échec.

##### Le provisionneur local-exec

local-exec permet d'exécuter une commande sur ta machine locale (ou le runner CI/CD) après la création/destruction d'une ressource Terraform.
Contrairement à remote-exec qui s'exécute sur la ressource distante, local-exec s'exécute là où tourne Terraform.

* Il s'exécute une seule fois à la création (sauf when = destroy)
* Il ne se ré-exécute pas si tu fais un apply sans changement sur la ressource
* Pour le forcer à re-tourner → terraform taint <resource> ou terraform apply -replace

##### Pièges à éviter avec local-exec

local-exec ne s'exécute qu'à la création, pas à sa modification, pas à chaque apply. Si tu modifies la commande, elle ne se relance pas.

Le provisioner destroy ne s'exécute pas si tu fais terraform destroy -target sur une autre ressource qui supprime la tienne en cascade.

---

##### null_resource en Terraform

**C'est quoi ?**
Une ressource fictive — elle ne crée rien dans ton infrastructure. Son seul rôle est de porter des provisioners et des dépendances.
Terraform la gère comme n'importe quelle ressource (elle a un ID, un state), mais elle n'appelle aucun provider cloud

``` 
resource "null_resource" "exemple" {
# Rien de réel n'est créé
}
```

Le vrai intérêt : triggers
`triggers` est une map de strings. Si une valeur change entre deux apply → la null_resource est détruite et recrée → le provisioner se relance.

```
resource "null_resource" "kubectl_apply" {
triggers = {
# Terraform recrée cette ressource (et relance le provisioner)
# si l'une de ces valeurs change
manifest_hash = filemd5("./k8s/deployment.yaml")
cluster_id    = google_container_cluster.gke.id
}

provisioner "local-exec" {
command = "kubectl apply -f ./k8s/deployment.yaml"
}
}
```

##### Comparaison avec et sans null_resource

```
# ❌ Sans null_resource
resource "google_container_cluster" "gke" {
name = "mon-cluster"

provisioner "local-exec" {
command = "gcloud container clusters get-credentials ${self.name}"
}
# Si ça échoue → cluster tainted → destroy au prochain apply 💣
}

# ✅ Avec null_resource
resource "google_container_cluster" "gke" {
name = "mon-cluster"
# Propre, sans provisioner
}

resource "null_resource" "gke_kubeconfig" {
depends_on = [google_container_cluster.gke]

triggers = {
cluster_id = google_container_cluster.gke.id
}

provisioner "local-exec" {
command = "gcloud container clusters get-credentials ${google_container_cluster.gke.name} --region ${google_container_cluster.gke.location}"
}
# Si ça échoue → seule null_resource tainted → cluster intact ✅
}
```

##### Pourquoi terraform_data plutôt que null_resource ?
# null_resource → provider externe à déclarer
```
terraform {
required_providers {
    null = {
    source  = "hashicorp/null"
    version = "~> 3.0"
}
}
}

resource "null_resource" "exemple" {
    triggers = { ... }
}

# terraform_data → built-in, rien à déclarer
resource "terraform_data" "exemple" {
    triggers_replace = [...]
}
```
---

##### Ressources Taints

Si un provisionneur au moment de la création échoue, la ressource est marquée comme "Taint" (corrompue/contaminée) . Une ressource contaminée sera planifiée pour être détruite et recréée lors de la prochaine éxecution de la commande terraform apply. Terraform le fait car un provisionneur défaillant peut laisser une ressource dans un état semi-configuré. Parce que Terraform ne peut pas raisonner sur ce que fait le provisionneur, la seule façon de garantir la création correcte d'une ressource est de la recréer.

---

##### Sentinel Policy en Terraform
**C'est quoi ?**
Sentinel est un framework de policy-as-code intégré à HCP Terraform (et Terraform Enterprise). Il permet de définir des règles qui s'appliquent avant qu'un apply soit exécuté. Langage est Sentinel (propre à HashiCorp)

```
Pourquoi c'est utile ?
Sans Sentinel, n'importe qui avec les droits Terraform peut :

Créer une VM avec 64 CPUs en prod
Ouvrir un port 22 sur 0.0.0.0/0
Déployer dans une région non autorisée

Sentinel permet de l'interdire automatiquement.
```

Tu peux appliquer différents policy sets selon les workspaces — prod plus strict que dev.

### Organisation dans HCP Terraform
```
HCP Terraform
  │
  ├── Organization
  │     └── Policy Sets  ←── ensemble de policies Sentinel
  │           ├── policy 1 : restrict-regions
  │           ├── policy 2 : restrict-vm-size
  │           └── policy 3 : require-tags
  │
  └── Workspaces
        ├── workspace-prod  ←── policy set appliqué ici
        ├── workspace-staging
        └── workspace-dev   ←── autre policy set (plus souple)
```

---

##### HCP Terraform vs Terraform Enterprise

* HCP Terraform        →  SaaS, hébergé par HashiCorp (app.terraform.io)
* Terraform Enterprise →  Self-hosted, installé sur VOS serveurs

Fonctionnalités communes :
✅ Remote state management
✅ Sentinel policies
✅ Workspaces
✅ VCS integration (GitHub, GitLab...)
✅ Private module registry
✅ SSO / SAML
✅ Audit logs
✅ Team management

---

##### Les variables locals

Contrairement aux variables d’entrée, une variable locale n’est accessible que dans les expressions du module où elle a été déclarée. Les valeurs locales peuvent être utiles pour éviter de répéter plusieurs fois les mêmes valeurs ou expressions dans une configuration, mais si elles sont trop utilisées, elles peuvent également rendre la lecture d’une configuration difficile. On accède à une variable locale en la préfixant par local..

You can access local values in the module where you define them, but not in other modules. However, you can pass a local value to a child module as an argument.

Terraform treats multiple locals blocks as if they were defined in a single block but you can use separate blocks to organize your related values into visually distinct blocks to make it easier for users to understand your configuration.

---
##### How to Pass Input Variables to Terraform Modules

* Defining a variable in a module and passing a value to it is straightforward:

```
# modules/web-server/variables.tf - Inside the module
variable "instance_type" {
    description = "EC2 instance type"
    type        = string
    default     = "t3.micro"
}

variable "server_name" {
    description = "Name tag for the instance"
    type        = string
    # No default - this is required
}


# main.tf - The caller passes values as arguments
module "web" {
    source = "./modules/web-server"
    
    server_name   = "production-web"
    instance_type = "t3.large"
}
```

---

##### Variable Validation
Validation runs before any resources are planned, so callers get immediate feedback about invalid configurations.
Add validation blocks to catch configuration errors before Terraform tries to create resources:

```
variable "environment" {
    description = "Deployment environment"
    type        = string
    
    validation {
        condition     = contains(["dev", "staging", "prod"], var.environment)
        error_message = "Environment must be one of: dev, staging, prod."
}
}

variable "instance_count" {
    description = "Number of instances to create"
    type        = number

    validation {
        condition     = var.instance_count >= 1 && var.instance_count <= 100
        error_message = "Instance count must be between 1 and 100."
}
}

variable "cidr_block" {
    description = "CIDR block for the VPC"
    type        = string
    
    validation {
        condition     = can(cidrnetmask(var.cidr_block))
        error_message = "Must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
}
}
```

---

##### Nullable Variables
By default, variables cannot be set to null unless you explicitly allow it

---
**very important** 

Terraform only queries cloud apis for resources already present in state

---

❌ You cannot use Terraform variables inside a backend block.
✅ The backend configuration must be static at init time.

Terraform initializes the backend before:
* Loading input variables
* Evaluating locals
* Processing modules

**Only literal values supported by the backend type.**

---

`terraform init --upgrade` tells Terraform:

🔄 Reinitialize the working directory and upgrade provider/module versions to the newest versions allowed by your version constraints.

---

ignore_changes dans le bloc lifecycle ignore les différences entre state et config.
Peu importe l’origine.
