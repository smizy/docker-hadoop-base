FROM java:8-jre-alpine
MAINTAINER smizy

ENV HADOOP_VERSION     2.7.2
ENV HADOOP_PREFIX      /usr/local/hadoop-${HADOOP_VERSION}
ENV HADOOP_HOME        ${HADOOP_PREFIX}
ENV HADOOP_COMMON_HOME ${HADOOP_PREFIX}
ENV HADOOP_HDFS_HOME   ${HADOOP_PREFIX}
ENV HADOOP_MAPRED_HOME ${HADOOP_PREFIX}
ENV HADOOP_YARN_HOME   ${HADOOP_PREFIX}
ENV HADOOP_CONF_DIR    ${HADOOP_PREFIX}/etc/hadoop 
ENV HADOOP_LOG_DIR     /var/log/hdfs
ENV YARN_CONF_DIR      ${HADOOP_PREFIX}/etc/hadoop
ENV YARN_HOME          ${HADOOP_PREFIX}
ENV YARN_LOG_DIR       /var/log/yarn
ENV PATH               $PATH:${HADOOP_PREFIX}/sbin:${HADOOP_PREFIX}/bin

ENV HADOOP_HEAPSIZE    1024  
ENV HADOOP_CLUSTER_NAME hadoop

RUN apk --no-cache add \
    bash \
    su-exec \
    #
    # download
    #
    && set -x \
    && mirror_url=$( \
        wget -q -O - http://www.apache.org/dyn/closer.cgi/hadoop/common/ \
        | sed -n 's#.*href="\(http://ftp.[^"]*\)".*#\1#p' \
        | head -n 1 \
    ) \
    && wget -q -O - ${mirror_url}/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
       | tar -xzf - -C /usr/local \
    && env \
       | grep -E '^(JAVA|HADOOP|PATH|YARN)' \
       | sed 's/^/export /g' \
       > ~/.profile \
    && cp ~/.profile /etc/profile.d/hadoop \
    && sed -i 's@${JAVA_HOME}@'${JAVA_HOME}'@g' ${HADOOP_CONF_DIR}/hadoop-env.sh \     
    # 
    # user/dir/permission
    #
    && adduser -D -g '' -s /sbin/nologin -u 1000 docker \
    && for user in hadoop hdfs yarn mapred; do \
         adduser -D -g '' -s /sbin/nologin ${user}; \
       done \
    && for user in root hdfs yarn mapred docker; do \
         adduser ${user} hadoop; \
       done \      
    && mkdir -p \
        /hadoop/dfs \
        /hadoop/yarn \
        /hadoop/mapred \
        /hadoop/nm-local-dir \
        /hadoop/yarn-nm-recovery \
        /var/log/hdfs \
        /var/log/yarn \       
    && chmod -R 775 /var/log/hdfs /var/log/yarn \
    && chmod -R 700 /hadoop/dfs \
    && chown -R hdfs:hadoop /hadoop/dfs /var/log/hdfs  \
    && chown -R yarn:hadoop /hadoop/yarn /var/log/yarn \
        /hadoop/nm-local-dir /hadoop/yarn-nm-recovery \
    && chown -R mapred:hadoop /hadoop/mapred    

COPY etc/*.xml  ${HADOOP_CONF_DIR}/
COPY etc/*.sh   /usr/local/bin/

RUN set -x \
    && sed -i 's/CLUSTER_NAME/'${HADOOP_CLUSTER_NAME}'/g' ${HADOOP_CONF_DIR}/*.xml 
        
WORKDIR ${HADOOP_COMMON_HOME}

VOLUME ["/hadoop", "/var/log/hdfs", "/var/log/yarn"]