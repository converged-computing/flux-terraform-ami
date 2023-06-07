#!/bin/bash

export AWS_ACCESS_KEY_ID=<>
export AWS_SECRET_ACCESS_KEY=<>
export AWS_SESSION_TOKEN=<>
export AWS_DEFAULT_REGION=<>

export TF_VAR_aws_secret=$AWS_SECRET_ACCESS_KEY 
export TF_VAR_aws_key=$AWS_ACCESS_KEY_ID 
export TF_VAR_aws_session=$AWS_SESSION_TOKEN 