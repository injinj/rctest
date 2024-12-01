#!/bin/bash

hosts=$(cat hosts.txt)
cwd=$(pwd)

raims_cfg_file="${cwd}/network.yaml"
cat > raims.service <<XXX
[Unit]
Description=raims
[Service]
ExecStart=/usr/bin/ms_server -d ${raims_cfg_file} -l /var/log/raims.log
Restart=always
RestartSec=5
XXX

cat > snap.service <<XXX
[Unit]
Description=snap
[Service]
ExecStart=${cwd}/snap.sh
Restart=always
RestartSec=30
XXX

replay_file="${cwd}/rsf4_sass.dat"
replay_network="-service 3333"
cat > replayrv.service <<XXX
[Unit]
Description=replay
[Service]
ExecStart=/usr/rai/bin/replayrv2 -perSec 100 -fileName ${replay_file} ${replay_network}
Restart=always
RestartSec=30
XXX

cat > hb.service <<XXX
[Unit]
Description=hb
[Service]
ExecStart=${cwd}/hb.sh
Restart=always
RestartSec=30
XXX

cat > pub1m.service <<XXX
[Unit]
Description=pub1m
[Service]
ExecStart=/usr/bin/rv_pub -T -x -m 1 -p 1000000 -k 16 ${h}.%%d
Restart=always
RestartSec=30
XXX

allh=
for h in $hosts ; do
allh="${allh} ${h}.%%d"
done

cat > sub1m.service <<XXX
[Unit]
Description=sub1m
[Service]
ExecStart=/usr/bin/rv_client -t 10m -q -A -x -k 1:16 ${allh}
Restart=always
RestartSec=5
XXX

cache_cfg_file="${cwd}/cache.xml"
cat > raicache.service <<XXX
[Unit]
Description=raicache
[Service]
ExecStart=/usr/rai/bin/raicache -cfg ${cache_cfg_file}
Restart=always
RestartSec=30
XXX

#jfor h in $hosts ; do
#echo "----> ${h}"
#ssh $h sudo ln -s -f '${cwd}/hb.service' /etc/systemd/system/
#done

