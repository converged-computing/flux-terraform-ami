#!/bin/bash

secret_token=pancakes-chicken-finger-change-me

flux submit -N 3  --error ./k3s_starter.out --output ./k3s_starter.out sh ./k3s_starter.sh "${secret_token}"
