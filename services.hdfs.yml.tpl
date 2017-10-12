version: "2"

services:

## journalnode
  journalnode-${i}:
    container_name: journalnode-${i}
    networks: ["${network_name}"]
    hostname: journalnode-${i}.${network_name}
    image: smizy/hadoop-base:3.0.0-beta1-alpine
    expose: [8480, 8485]
    environment:
      - SERVICE_8485_NAME=journalnode
      - SERVICE_8480_IGNORE=true
      - HADOOP_ZOOKEEPER_QUORUM=${ZOOKEEPER_QUORUM} 
      - HADOOP_HEAPSIZE=1000
      - HADOOP_NAMENODE_HA=${NAMENODE_HA}
      ${SWARM_FILTER_JOURNALNODE_${i}}
    command: journalnode
##/ journalnode

## namenode
  namenode-${i}:
    container_name: namenode-${i}
    networks: ["${network_name}"]
    hostname: namenode-${i}.${network_name}
    image: smizy/hadoop-base:3.0.0-beta1-alpine 
    expose: ["9820"]
    ports:  ["9870"]
    environment:
      - SERVICE_9820_NAME=namenode
      - SERVICE_9870_IGNORE=true
      - HADOOP_ZOOKEEPER_QUORUM=${ZOOKEEPER_QUORUM} 
      - HADOOP_HEAPSIZE=1000
      - HADOOP_NAMENODE_HA=${NAMENODE_HA}
      ${SWARM_FILTER_NAMENODE_${i}}
    entrypoint: entrypoint.sh
    command: namenode-${i}
##/ namenode

## datanode
  datanode-${i}:
    container_name: datanode-${i}
    networks: ["${network_name}"]
    hostname: datanode-${i}.${network_name}
    image: smizy/hadoop-base:3.0.0-beta1-alpine
    expose: ["9866", "9867", "9864"]
    environment:
      - SERVICE_9866_NAME=datanode
      - SERVICE_9867_IGNORE=true
      - SERVICE_9864_IGNORE=true
      - HADOOP_ZOOKEEPER_QUORUM=${ZOOKEEPER_QUORUM} 
      - HADOOP_HEAPSIZE=1000
      - HADOOP_NAMENODE_HA=${NAMENODE_HA}
      ${SWARM_FILTER_DATANODE_${i}}
    entrypoint: entrypoint.sh
    command: datanode
##/ datanode 