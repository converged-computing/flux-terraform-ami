# Autoscale

See the main [../../README.md](README.md) for instructions. Note that if your VM
has Flux but not systemd, here is the last set of commands you can run instead of
restarting the service:

```bash
mkdir -p /tmp/run/flux /var/lib/flux
# Broker options shared between flux start and flux broker
brokerOpts="-Scron.directory=/usr/local/etc/flux/system/cron.d  \
     -Srundir=/run/flux   
     -Sstatedir=/var/lib/flux   
     -Slocal-uri=local:///run/flux/local   
     -Slog-stderr-level=6   
     -Slog-stderr-mode=local   
     -Sbroker.rc2_none   
     -Sbroker.quorum=0   
     -Sbroker.quorum-timeout=none   
     -Sbroker.exit-norestart=42   
     -Scontent.restore=auto 
     -Slog-stderr-mode=local 
     -Stbon.zmqdebug=1"

broker=$(echo $NODELIST | cut -d"," -f1)

# TODO need to look at and debug permissions of things. For now, this seems to work.
# I only put this here if we eventually want separate logic
if [[ $(hostname) == "$broker" ]]; then
   echo "Hello I am the broker, $(hostname)"
   /usr/local/bin/flux broker --config-path=/usr/local/etc/flux/system/conf.d $brokerOptions
else
   echo "Hello I am a worker, $(hostname)"
   /usr/local/bin/flux start -o --config /usr/local/etc/flux/system/conf.d $brokerOptions
fi
```

With the current builds, the above commands are done with the `flux.service` via systemd.
so you might only need these for debugging.

## Developer

### AMIs

The following AMIs have been used at some point in this project:

  - `ami-0ff535566e7c13e8c`: current AMI, modified to have cgroups version 2 
  - `ami-02eac56446a475861`: original AMI, early 2023 (March-May) without cgroups 2

### Credentials

The best practice approach for giving the instances ability to list images (and get the hostnames)
is with an IAM role. However, we used a previous approach to add credentials (scoped) directly to
the environment in the startscript. That looked like this:

Since we want to get hosts on the instance using the aws client, export your credentials to the environment
for the instances:

```bash
export TF_VAR_aws_secret=$AWS_SECRET_ACCESS_KEY 
export TF_VAR_aws_key=$AWS_ACCESS_KEY_ID 
export TF_VAR_aws_session=$AWS_SESSION_TOKEN 
```

And then see [this commit](https://github.com/converged-computing/flux-terraform-ami/blob/7d416d2d20ce8b16d577caac624ef6c744b730ec/examples/autoscale/main.tf) for the full recipe at the time.
