# Currently Under Construction

# Instructions
Assumes you already have the image from the main instructions [../../README.md](README.md) 
And then init and build:

```bash
$ make init
$ make fmt
$ make validate
$ make build
```

Or they all can be run with `make`:

```bash
$ make
```
### Upload K3S starter script and flux job submit into the nodes
```bash
$ scp -i "mykey.pem" <filename> rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

You can then shell into any node, and check the status of K3S.

```bash
$ ssh -o 'IdentitiesOnly yes' -i "mykey.pem" rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

### Now, Run flux job that will start K3S
Be sure to change k3s secret value, number of instances, and any modifications!

```bash
$ ./flux_submit_job.sh
```

You can look at the script logs/ runtime logs like this if you need to debug.
```bash
$ cat $HOME/<script_name>.out
```

That's it. Enjoy!

## Developer

### AMIs

The following AMIs have been used at some point in this project:

  - `ami-0ff535566e7c13e8c`: current AMI, modified to have cgroups version 2 
  - `ami-02eac56446a475861`: original AMI, early 2023 (March-May) without cgroups 2

### Credentials

The best practice approach for giving the instances ability to list images (and get the hostnames)
is with an IAM role. However, we used a previous approach to add credentials (scoped) directly to
the environment in the startscript. That looked like this:

```
Since we want to get hosts on the instance using the aws client, export your credentials to the environment
for the instances:

```bash
export TF_VAR_aws_secret=$AWS_SECRET_ACCESS_KEY 
export TF_VAR_aws_key=$AWS_ACCESS_KEY_ID 
export TF_VAR_aws_session=$AWS_SESSION_TOKEN 
```

Thanks [Vsoch](https://github.com/vsoch)
