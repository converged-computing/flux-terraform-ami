# Currently Under Construction

# Instructions

## Export AWS credentials to environment variables.

```bash
export AWS_ACCESS_KEY_ID=<>
export AWS_SECRET_ACCESS_KEY=<>
export AWS_SESSION_TOKEN=<>
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_aws_secret=$AWS_SECRET_ACCESS_KEY 
export TF_VAR_aws_key=$AWS_ACCESS_KEY_ID 
export TF_VAR_aws_session=$AWS_SESSION_TOKEN 
```

Assumes you already have the image from the main instructions [README.md](../../README.md) 
And then init and build:

Note: By Default, the instances only allow ssh from the specific machines. Change `ip_address_allowed` from the `main.tf` file according to your needs. 

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
K3S binary will be available in the instances once they are launched.

### Upload K3S starter script and flux job submit script to ALL the nodes
The important files for K3S setup are - [k3s_starter.sh](../scripts/k3s_starter.sh), [k3s_cleanup.sh](../scripts/k3s_cleanup.sh), [k3s_agent_cleanup.sh](../scripts/k3s_agent_cleanup.sh). If you use git clone, make sure you change the directory in [k3s_starter.sh](scripts/k3s_starter.sh) so that it points to the cleaning files. Optionally, you can upload from your local directory to the instances following the below commands. [flux_batch_job.sh](../scripts/flux_batch_job.sh) run all the necessary files to install k3s along with your hpc jobs.

```bash
$ scp -i "mykey.pem" k3s_starter.sh rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
$ scp -i "mykey.pem" k3s_cleanup.sh rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
$ scp -i "mykey.pem" k3s_agent_cleanup.sh rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
$ scp -i "mykey.pem" flux_batch_job.sh rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

### Note: the k3s deployment script (k3s_starter.sh) assume the clean up scripts are in the user home directory.

You can then shell into any node, and submit flux jobs.

```bash
$ ssh -o 'IdentitiesOnly yes' -i "mykey.pem" rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

### Now, Run flux job that will start K3S, and will run your workload
Be sure to change k3s secret value, number of instances, and any modifications!
The below command runs a job with three nodes. 

```bash
$ flux batch -N 3 --error k3s_installation.out --output k3s_installation.out flux_batch_job.sh "k3s_secret_token"
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
