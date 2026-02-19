Terraform.tfstate is a JSON file that is essentially Terraform's memory of your infrastructure. It records all the resources Terraform has created or managed on your behalf and tracks their current state, using this information to map the real-world resources back to your configuration.

When you run terraform plan, Terraform looks at this file to understand your current state and what changes need to be made to match your desired state. Although terraform plan doesn't modify the terraform.tfstate file, it reads from it to generate the plan. 


#### terraform.tfstate.lock.info

When Terraform begins an operation that will modify the state, such as terraform apply, it creates this lock file.
The lock file indicates to other Terraform processes that the state is currently being modified and that they should only attempt to make changes once the lock is released.

Once the operation is complete, Terraform automatically deletes the .terraform.tfstate.lock.info file, releasing the lock and allowing other operations to proceed.