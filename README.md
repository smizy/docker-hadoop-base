# docker-hadoop-base

[![](https://imagelayers.io/badge/smizy/hadoop-base:2.7.2-alpine.svg)](https://imagelayers.io/?images=smizy/hadoop-base:2.7.2-alpine 'Get your own badge on imagelayers.io')

Hadoop(Common/HDFS/YARN/MapReduce) docker image based on jre-8:alpine

* Namenode is set to high availability mode.
* Non secure mode
* Native-hadoop library missing
* conf template applied by mustache.sh

This setup use FQDN with docker embedded DNS instead of editing /etc/hosts. 
Using FQDN on Hadoop require dns lookup and reverse lookup. 

So, you need set --name and --net (container_name.network_name as hostname) for dns lookup from other containers 
, and set --hostname(-h) for reverse lookup from container itself.

## manual cluster setup on single docker host
 
```
# build
docker build -t local/hadoop-base:2.7.2-alpine .

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
-d local/hadoop-base:2.7.2-alpine \
entrypoint.sh journalnode \
;done 

# namenode
for i in 1 2; do docker run \
--name namenode-$i \
--net vnet \
-h namenode-$i.vnet \
--expose 8020 \
--expose 50070 \
-d local/hadoop-base:2.7.2-alpine \
entrypoint.sh namenode-$i \
;done 

# datanode
for i in 1 2 3; do docker run \
--name datanode-$i \
--net vnet \
-h datanode-$i.vnet \
--expose 50010 \
--expose 50020 \
--expose 50075 \
-d local/hadoop-base:2.7.2-alpine \
entrypoint.sh datanode \
;done 

# yarn resourcemanager
for i in 1; do docker run \
--name resourcemanager-$i \
--net vnet \
-h resourcemanager-$i.vnet \
--expose 8030-8033 \
-p 8088:8088 \
-d local/hadoop-base:2.7.2-alpine \
entrypoint.sh resourcemanager \
;done 

# yarn nodemanager
for i in 1 2 3 ; do docker run \
--name nodemanager-$i \
--net vnet \
-h nodemanager-$i.vnet \
--expose 8040-8042 \
--volumes-from datanode-$i \
-d local/hadoop-base:2.7.2-alpine \
entrypoint.sh nodemanager \
;done 
  
# run example data
docker exec -it -u hdfs nodemanager-1 hdfs dfs -mkdir /user 
docker exec -it -u hdfs nodemanager-1 hdfs dfs -mkdir /user/hdfs
docker exec -it -u hdfs nodemanager-1 hdfs dfs -put etc/hadoop input
docker exec -it -u hdfs nodemanager-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.2.jar grep input output 'dfs[a-z.]+'
docker exec -it -u hdfs nodemanager-1 hdfs dfs -cat output/*

```