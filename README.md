To enable debug logging for terraform commands :
- export environnement variable TF_LOG : `export TF_LOG=DEBUG` , we can use other levels like TRACE
- execute terraform command

State file are stored locally by default

TF backup my last state file after successful tf apply 

Remote state storage mecanism : we can store the state remotly (aws s3, google storage,  etc)  =>  Allows sharing state file between distributed teams, Allows locking state so parallel executions don't coincide, Enables sharing "output" values with other Terraform configuration or code  

### **Terraform commands**
`terrafrom destory` : destroy **only** resources that exists in the state file , so if we remove a resource from the state file(using terraform state rm or manually) then execute destroy command, the resource still exist

`terraform state list` :  list all resources that terraform is tracking

`terraform state show <resource-name>` : to see details of a specific resource

