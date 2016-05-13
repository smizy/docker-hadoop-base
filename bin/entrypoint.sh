#!/bin/bash

set -eo pipefail

wait_until() {
    local hostname=${1?}
    local port=${2?}
    local retry=${3:-100}
    local sleep_secs=${4:-2}
    
    local address_up=0
    
    while [ ${retry} -gt 0 ] ; do
        echo  "Waiting until ${hostname}:${port} is up ... with retry count: ${retry}"
        if nc -z ${hostname} ${port}; then
            address_up=1
            break
        fi        
        retry=$((retry-1))
        sleep ${sleep_secs}
    done 
    
    if [ $address_up -eq 0 ]; then
        echo "GIVE UP waiting until ${hostname}:${port} is up! "
        exit 1
    fi       
}

# apply template
for template in $(ls ${HADOOP_CONF_DIR}/*.mustache)
do
    conf_file=${template%.mustache}
    cat ${conf_file}.mustache | mustache.sh > ${conf_file}
done


if  [ "$1" == "journalnode" ]; then
    exec su-exec hdfs hdfs journalnode
    
elif [ "$1" == "namenode-1" ]; then
    if [ ! -e "${HADOOP_TMP_DIR}/dfs/name/current/VERSION" ]; then
        su-exec hdfs hdfs namenode -format -force
        su-exec hdfs hdfs zkfc -formatZK -force
    fi        
    su-exec hdfs hdfs zkfc &        
    exec su-exec hdfs hdfs namenode
    
elif [ "$1" == "namenode-2" ]; then
    if [ ! -e "${HADOOP_TMP_DIR}/dfs/name/current/VERSION" ]; then
        
        wait_until ${HADOOP_NAMENODE1_HOSTNAME} 8020 
             
        su-exec hdfs hdfs namenode -bootstrapStandby
    fi    
    
    su-exec hdfs hdfs zkfc &
    exec su-exec hdfs hdfs namenode

elif [ "$1" == "datanode" ]; then
    exec su-exec hdfs hdfs datanode
       
elif [ "$1" == "resourcemanager" ]; then
    exec su-exec yarn yarn resourcemanager

elif [ "$1" == "nodemanager" ]; then
    exec su-exec yarn yarn nodemanager
    
elif [ "$1" == "historyserver" ]; then
    
    wait_until ${HADOOP_NAMENODE1_HOSTNAME} 8020 
    
    su-exec hdfs hdfs dfs -mkdir -p /tmp/hadoop-yarn/staging/history
    su-exec hdfs hdfs dfs -chmod -R 1777 /tmp
    su-exec hdfs hdfs dfs -chown -R mapred:hadoop /tmp/hadoop-yarn
    su-exec mapred hdfs dfs -mkdir -p /tmp/hadoop-yarn/apps
           
    exec su-exec mapred mapred historyserver    
fi

exec "$@"

 
