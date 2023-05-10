.PHONY: all
all: init fmt validate build

.PHONY: init
init: 
	packer init .
	
.PHONY: fmt
fmt: 
	packer fmt .

.PHONY: validate
validate: 
	packer validate .
	
.PHONY: build
build: 
	# Rocky-8-EC2-Base-8.7-20230215.0.x86_64-d6577ceb-8ea8-4e0e-84c6-f098fc302e82
	packer build -var region=us-east-1 -var source_ami=ami-09d91a87b002fc97a -var instance_type=m4.large compute.pkr.hcl
