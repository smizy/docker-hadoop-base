# docker-hadoop-base

[![](https://imagelayers.io/badge/smizy/hadoop-base:2.7.2-alpine.svg)](https://imagelayers.io/?images=smizy/hadoop-base:2.7.2-alpine 'Get your own badge on imagelayers.io')

Hadoop(Common/HDFS/YARN/MapReduce) docker image based on jre-8:alpine

* Namenode is set to high availability mode.
* Non secure mode
* Native-hadoop library missing
* Not sshd setting, you cannot use sbin/start-*.sh. use docker-compose or docker engine to start/stop daemon 
* conf template applied by mustache.sh

This setup use FQDN with docker embedded DNS instead of editing /etc/hosts. 
Using FQDN on Hadoop require dns lookup and reverse lookup. 

So, you need set --name and --net (container_name.network_name as hostname) for dns lookup from other containers 
, and set --hostname(-h) for reverse lookup from container itself.


## setup pseudo-distributed hadoop cluster on a single docker host  

* The following sample uses docker host named "default" on virtualbox

```
# load default env
eval $(docker-machine env default)

# network 
docker network create vnet

# up zookeeper, journalnode, namenode, datanode, resouremanager, nodemanager
docker-compose up -d

# check stats
docker ps --format {{.Names}} | xargs docker stats

# run example data (pi calc)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.2.jar pi 10 10

# cleanup  
docker-compose kill
docker-compose rm -f

```


## setup fully-distributed hadoop cluster on a swarm cluster 

* create 6 docker hosts. manager-1, manager-2, manager-3, node-d-1, node-d-2, node-d-3
* need 3G total memory (each 512MB)

  
```
# create manager node on virtualbox with docker-machine and start consul/swarm master
for i in 1 2 3; do \
  docker-machine create \
  -d virtualbox \
  --virtualbox-memory 512 \
  --engine-opt="cluster-store=consul://localhost:8500" \
  --engine-opt="cluster-advertise=eth1:2376" \
  --swarm \
  --swarm-discovery consul://localhost:8500 \
  --swarm-master \
  --swarm-opt replication \
  manager-$i 
  
  # consul server 
  docker $(docker-machine config manager-$i) run -d \
  --name consul-server \
  --net host \
  --restart unless-stopped \
  gliderlabs/consul-server:0.6 \
  -server -bootstrap-expect 3  \
  -bind $(docker-machine ip manager-$i) 
done

# consul-server join
docker $(docker-machine config manager-1) exec -it consul-server consul join \
  $(docker-machine ip manager-1) $(docker-machine ip manager-2) $(docker-machine ip manager-3)

# check consul members 
docker $(docker-machine config manager-1) exec -it consul-server consul members

# create data node and start consul/swarm agent on virtualbox with docker-machine
for i in 1 2 3; do \
  docker-machine create \
  -d virtualbox \
  --virtualbox-memory 512 \
  --engine-opt="cluster-store=consul://localhost:8500" \
  --engine-opt="cluster-advertise=eth1:2376" \
  --swarm \
  --swarm-discovery consul://localhost:8500 \
  node-d-$i; 
  
  docker $(docker-machine config node-d-$i) run -d \
  --name consul-agent \
  --net host \
  --restart unless-stopped \
  gliderlabs/consul-agent:0.6 \
  -bind $(docker-machine ip node-d-$i)
  
  # consul-agent join
  docker $(docker-machine config node-d-$i) exec -it consul-agent consul join \
  $(docker-machine ip manager-1) $(docker-machine ip manager-2) $(docker-machine ip manager-3)    
done

# check consul members 
docker $(docker-machine config node-d-1) exec -it consul-agent consul members
 
# registrator
for i in manager-1 manager-2 manager-3 node-d-1 node-d-2 node-d-3; do \
  docker $(docker-machine config ${i}) run -d \
  --name registrator \
  --net host \
  --restart unless-stopped \
  -v /var/run/docker.sock:/tmp/docker.sock \
  gliderlabs/registrator -internal  consul://localhost:8500 
done 

# load swarm-enabled env
eval $(docker-machine env --swarm manager-1)

# create overlay network
docker $(docker-machine config manager-1) network create -d overlay vnet

# up zookeeper, journalnode, namenode, datanode, resouremanager, nodemanager
docker-compose -f docker-compose.fully.yml up -d

# check ps
docker-compose -f docker-compose.fully.yml ps

# check consul ui
open http://$(docker-machine ip manager-1):8500/ui
 
# check stats
docker ps --format {{.Names}} | xargs docker stats

# check hadoop process stats
docker ps --format {{.Names}} | grep -Ev 'consul|registrator'  | xargs docker stats
  
# run example (pi calc)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.2.jar pi 10 10

# prepare sample data
docker exec -it -u hdfs datanode-1 hdfs dfs -put etc/hadoop input
docker exec -it -u hdfs datanode-1 hdfs dfs -ls /user/hdfs/input

# run example (grep count)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.2.jar grep input output 'dfs[a-z.]+'
docker exec -it -u hdfs datanode-1 hdfs dfs -cat output/*

# run example (word count)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.2.jar wordcount input/hadoop-env.sh output2
docker exec -it -u hdfs datanode-1 hdfs dfs -cat output2/*

# cleanup  
docker-compose -f docker-compose.fully.yml kill
docker-compose -f docker-compose.fully.yml rm -f 

```