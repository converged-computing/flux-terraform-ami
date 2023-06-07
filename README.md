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
# this builds a shared node setup
$ make node
```

Note that the build takes about 50 minutes (why we use an AMI and don't build Flux on the fly!

```console
==> flux-compute.amazon-ebs.flux-compute: Deleting temporary keypair...
Build 'flux-compute.amazon-ebs.flux-compute' finished after 50 minutes 39 seconds.

==> Wait completed after 50 minutes 39 seconds

==> Builds finished. The artifacts of successful builds are:
--> flux-compute.amazon-ebs.flux-compute: AMIs were created:
us-east-1: ami-0ff535566e7c13e8c

make[1]: Leaving directory '/home/vanessa/Desktop/Code/flux/terraform-ami/build-images/node'
```

A previous design (building separate images for login, compute, and manager) was started,
but not finished in lieu of the simpler design. It's included in [build-images/multi](build-images/multi)
for those interested.

### Deploy with Terraform

Once you have images, choose a directory under [examples](examples) to deploy from:

```bash
$ cd examples/autoscale
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

Check the cluster status, the overlay status, and try running a job:

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

## License

HPCIC DevTools is distributed under the terms of the MIT license.
All new contributions must be made under this license.

See [LICENSE](https://github.com/converged-computing/cloud-select/blob/main/LICENSE),
[COPYRIGHT](https://github.com/converged-computing/cloud-select/blob/main/COPYRIGHT), and
[NOTICE](https://github.com/converged-computing/cloud-select/blob/main/NOTICE) for details.

SPDX-License-Identifier: (MIT)

LLNL-CODE- 842614
