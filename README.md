# docker-hadoop-base
Light weight hadoop-base docker image based on java:8-jre-alpine

## manual cluster setup
The following is non-secure hadoop cluster setup on single docker host
using docker bridge network.

 
```
# network
docker network create vnet

# build
docker build -t smizy/hadoop-base:2.7.2-alpine .

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