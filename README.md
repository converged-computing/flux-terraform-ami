# Flux Terraform AMI

Terraform module to create Amazon Machine Images (AMI) for Flux Framework HashiCorp Packer and AWS CodeBuild.
We are mirroring functionality from [GoogleCloudPlatform/scientific-computing-examples](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/openmpi/fluxfw-gcp). Thank you Google, we love you!

## Usage

### Build Images with Packer

Let's first go into [build-images](build-images) to use packer to build our images.
You'll need to export your AWS credentials in the environment:

```bash
export AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

You'll need to first [install packer](https://developer.hashicorp.com/packer/downloads)
You can use the Makefile there to build all (or a select set of) images.

```bash
cd ./build-images
```
```bash
$ make
# or, for shared node setup, recommended
$ make node
# or
$ make compute
$ make login    # not done yet
$ make manager  # not done yet
```
These are under development! My plan is to finish the base images, and then
figure out bringing them all up, and likely we will need a common metadata Api
for different sets of images to see one another, from a networking standpoint.
Stay tuned!

### Deploy with Terraform

Once you have images, choose a directory under [examples](examples) to deploy from:

```bash
$ cd examples/autoscale
```

Since we want to get hosts on the instance using the aws client, export your credentials to the environment
for the instances:

```bash
export TF_VAR_aws_secret=$AWS_SECRET_ACCESS_KEY 
export TF_VAR_aws_key=$AWS_ACCESS_KEY_ID 
export TF_VAR_aws_session=$AWS_SESSION_TOKEN 
```

And then init and build:

```bash
$ make init
$ make fmt
$ make validate
$ make build
```

And they all can be run with `make`:

```bash
$ make
```

You can then shell into any node, and check the status of Flux. I usually grab the instance
name via "Connect" in the portal, but you could likely use the AWS client for this too.

```bash
$ ssh -o 'IdentitiesOnly yes' -i "mykey.pem" rocky@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

Check the cluster status and try running a job:

```bash
$ flux resource list
     STATE NNODES   NCORES NODELIST
      free      2        2 i-012fe4a110e14da1b.ec2.internal,i-0354d878a3fd6b017.ec2.internal
 allocated      0        0 
      down      0        0 
```
```bash
[rocky@i-012fe4a110e14da1b ~]$ flux run -N 2 hostname
i-012fe4a110e14da1b.ec2.internal
i-0354d878a3fd6b017.ec2.internal
```

You can look at the startup script logs like this if you need to debug.
```bash
$ cat /var/log/cloud-init-output.log
```

That's it. Enjoy!
