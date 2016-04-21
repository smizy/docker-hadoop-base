# docker-hadoop-base
Lightweight hadoop-common docker image (based on alpine)
[![](https://imagelayers.io/badge/smizy/hadoop-base:2.7.2-alpine.svg)](https://imagelayers.io/?images=smizy/hadoop-base:2.7.2-alpine 'Get your own badge on imagelayers.io')

* Namenode is set to high availability mode.
* Non secure mode
* Native-hadoop library missing

The following master FQDN and size is fixed.
See `etc/*.xml` like `hdfs-site.xml`.

* zookeeper-1.vnet, zookeeper-2.vnet, zookeeper-3.vnet
* namenode-1.vent, namenode-2.vnet
* journalnode-1.vnet, journalnode-2.vent, journalnode-3.vnet
* resourcemanager-1.vnet

Using FQDN on Hadoop require dns lookup and reverse lookup. 

This setup use FQDN with docker embedded DNS instead of editing /etc/hosts. 

So, you need set --name and --net (container_name.network_name as hostname) for dns lookup from other containers 
, and set --hostname(-h) for reverse lookup from container itself.

## manual cluster setup on single docker host
 
```
# network
docker network create vnet

# zookeeper
for i in 1 2 3; do docker run \
--name zookeeper-$i \
--net vnet \
-h zookeeper-$i.vnet \
-d smizy/zookeeper:3.4-alpine \
-server $i 3 \
;done

# journalnode
for i in 1 2 3; do docker run \
--name journalnode-$i \
--net vnet \
-h journalnode-$i.vnet \
--expose 8480 \
--expose 8485 \
-d smizy/hadoop-base:2.7.2-alpine \
entrypoint.sh journalnode \
;done 

# namenode
for i in 1 2; do docker run \
--name namenode-$i \
--net vnet \
-h namenode-$i.vnet \
--expose 8020 \
--expose 50070 \
--expose 50470 \
-d smizy/hadoop-base:2.7.2-alpine \
entrypoint.sh namenode-$i \
;done 

# datanode
for i in 1 2 3; do docker run \
--name datanode-$i \
--net vnet \
-h datanode-$i.vnet \
-d smizy/hadoop-base:2.7.2-alpine \
entrypoint.sh datanode \
;done 

# yarn resourcemanager
for i in 1; do docker run \
--name resourcemanager-$i \
--net vnet \
-h resourcemanager-$i.vnet \
--expose 8030-8033 \
-p 18088:8088 \
-d smizy/hadoop-base:2.7.2-alpine \
entrypoint.sh resourcemanager \
;done 

# yarn nodemanager
for i in 1 2 3 ; do docker run \
--name nodemanager-$i \
--net vnet \
-h nodemanager-$i.vnet \
--expose 8040-8042 \
--volumes-from datanode-$i \
-d smizy/hadoop-base:2.7.2-alpine \
entrypoint.sh nodemanager \
;done 
  
```