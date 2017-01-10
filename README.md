# docker-hadoop-base

[![](https://images.microbadger.com/badges/image/smizy/hadoop-base:3.0.0-alpha1-alpine.svg)](http://microbadger.com/images/smizy/hadoop-base:3.0.0-alpha1-alpine "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/smizy/hadoop-base:3.0.0-alpha1-alpine.svg)](http://microbadger.com/images/smizy/hadoop-base:3.0.0-alpha1-alpine "Get your own image badge on microbadger.com")
[![CircleCI](https://circleci.com/gh/smizy/docker-hadoop-base.svg?style=shield&circle-token=155cf7c34ea00da94d6d7848796b96d62d95de48)](https://circleci.com/gh/smizy/docker-hadoop-base)

Hadoop(Common/HDFS/YARN/MapReduce) docker image based on alpine

* Namenode is set to high availability mode with multiple namenode
* Non secure mode
* Native-hadoop library missing
* One process per container as possible 
* No sshd setting. Cannot use utility script like start-dfs.sh and start-yarn.sh.  
* conf template applied by mustache.sh

This setup use FQDN with docker embedded DNS instead of editing /etc/hosts. 
Using FQDN on Hadoop require dns lookup and reverse lookup. 

You need set --name and --net (container_name.network_name as hostname) for dns lookup from other containers 
, and set --hostname(-h) for reverse lookup from container itself.


## Small setup  

```
# load default env as needed
eval $(docker-machine env default)

# network 
docker network create vnet

# make docker-compose.yml 
namenode=1 datanode=1 ./make_docker_compose_file.sh hdfs yarn > docker-compose.yml

# config test
docker-compose config

# hadoop startup (zookeeper, namenode, datanode, resourcemanager, nodemanager)
docker-compose up -d

# tail logs for a while
docker-compose logs -f

# check ps
docker-compose ps

# check stats
docker ps --format {{.Names}} | xargs docker stats

# run example data (pi calc)
docker exec -it -u hdfs datanode-1 hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.0.0-alpha1.jar pi 3 10

# view job history in web ui
open http://$(docker-machine ip default):19888

# hadoop shutdown  
docker-compose stop

# cleanup container
docker-compose rm -v

```
