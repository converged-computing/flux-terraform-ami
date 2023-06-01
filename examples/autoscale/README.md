# Autoscale

See the main [../../README.md](README.md) for instructions. Note that if you VM
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
