# docker-hadoop-base

[![](https://imagelayers.io/badge/smizy/hadoop-base:2.7.3-alpine.svg)](https://imagelayers.io/?images=smizy/hadoop-base:2.7.3-alpine 'Get your own badge on imagelayers.io')

Hadoop(Common/HDFS/YARN/MapReduce) docker image based on jre-8:alpine

* Namenode is set to high availability mode
* Non secure mode
* Native-hadoop library missing
* One process per container as possible 
* No sshd setting. Cannot use utility script like start-dfs.sh and start-yarn.sh.  
* conf template applied by mustache.sh

This setup use FQDN with docker embedded DNS instead of editing /etc/hosts. 
Using FQDN on Hadoop require dns lookup and reverse lookup. 

You need set --name and --net (container_name.network_name as hostname) for dns lookup from other containers 
, and set --hostname(-h) for reverse lookup from container itself.


## setup pseudo-distributed hadoop cluster on a single docker host  

```
# load default env as needed
eval $(docker-machine env default)

# network 
docker network create vnet

# make docker-compose.yml with pseudo hdfs, yarn services
env $(grep -v ^# pseudo.env ) ./make_docker_compose_file.sh hdfs yarn > docker-compose.yml

# config test
docker-compose config

# hadoop startup (zookeeper, journalnode, namenode, datanode, resouremanager, nodemanager, historyserver)
docker-compose up -d

# tail logs for a while
docker-compose logs -f

# check ps
docker-compose ps

# check stats
docker ps --format {{.Names}} | xargs docker stats

# run example data (pi calc)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar pi 10 10

# view job history in web ui
open http://$(docker-machine ip default):19888

# hadoop shutdown  
docker-compose stop

# cleanup container
docker-compose rm -v

```


## setup fully-distributed hadoop cluster on a swarm(v1.11) cluster 

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

# make docker-compose.yml with multihost(distributed) hdfs, yarn services
env $(grep -v ^# multihost.env ) ./make_docker_compose_file.sh hdfs yarn > docker-compose.yml

# config test
docker-compose config

# hadoop startup (zookeeper, journalnode, namenode, datanode, resouremanager, nodemanager, historyserver)
docker-compose up -d

# tail logs for a while
docker-compose logs -f

# check ps
docker-compose ps

# check consul ui
open http://$(docker-machine ip manager-1):8500/ui
 
# check stats
docker ps --format {{.Names}} | xargs docker stats

# check hadoop process stats
docker ps --format {{.Names}} | grep -Ev 'consul|registrator'  | xargs docker stats
  
# run example (pi calc)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar pi 10 10

# prepare sample data
docker exec -it -u hdfs datanode-1 hdfs dfs -put etc/hadoop input
docker exec -it -u hdfs datanode-1 hdfs dfs -ls /user/hdfs/input

# run example (grep count)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar grep input output 'dfs[a-z.]+'
docker exec -it -u hdfs datanode-1 hdfs dfs -cat output/*

# run example (word count)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar wordcount input/hadoop-env.sh output2
docker exec -it -u hdfs datanode-1 hdfs dfs -cat output2/*

# hadoop shutdown  
docker-compose stop

# cleanup container
docker-compose rm -v

```