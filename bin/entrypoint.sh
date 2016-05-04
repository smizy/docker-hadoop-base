#!/bin/bash

set -eo pipefail

. mustache.sh

# apply template
for template in $(ls ${HADOOP_CONF_DIR}/*.mustache)
do
    conf_file=${template%.mustache}
    cat ${conf_file}.mustache | mustache > ${conf_file}
done


if  [ "$1" == "journalnode" ]; then
    exec su-exec hdfs hdfs journalnode
    
elif [ "$1" == "namenode-1" ]; then
    if [ ! -e "${HADOOP_TMP_DIR}/dfs/name/current/VERSION" ]; then
        su-exec hdfs hdfs namenode -format -force
        su-exec hdfs hdfs zkfc -formatZK -force
        su-exec hdfs hdfs zkfc &        
    fi
    exec su-exec hdfs hdfs namenode
    
elif [ "$1" == "namenode-2" ]; then
    sleep 5
    su-exec hdfs hdfs namenode -bootstrapStandby 
    su-exec hdfs hdfs zkfc &
    exec su-exec hdfs hdfs namenode

elif [ "$1" == "datanode" ]; then
    exec su-exec hdfs hdfs datanode
       
elif [ "$1" == "resourcemanager" ]; then
    exec su-exec yarn yarn resourcemanager

elif [ "$1" == "nodemanager" ]; then
    exec su-exec yarn yarn nodemanager
fi

exec "$@"

 
