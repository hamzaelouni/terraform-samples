To enable debug logging for terraform commands :
- export environnement variable TF_LOG : `export TF_LOG=DEBUG` , we can use other levels like TRACE
- execute terraform command

### **Terraform commands**
`terrafrom destory` : destroy **only** resources that exists in the state file , so if we remove a resource from the state file(using terraform state rm or manually) then execute destroy command, the resource still exist

`terraform state list` :  list all resources that terraform is tracking

`terraform state show <resource-name>` : to see details of a specific resource

