FROM alpine:3.5
MAINTAINER smizy

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="Apache License 2.0" \
    org.label-schema.name="smizy/hadoop-base" \
    org.label-schema.url="https://github.com/smizy" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/smizy/docker-hadoop-base"

ENV HADOOP_VERSION      $VERSION
ENV HADOOP_HOME         /usr/local/hadoop-${HADOOP_VERSION}
ENV HADOOP_COMMON_HOME  ${HADOOP_HOME}
ENV HADOOP_HDFS_HOME    ${HADOOP_HOME}
ENV HADOOP_MAPRED_HOME  ${HADOOP_HOME}
ENV HADOOP_YARN_HOME    ${HADOOP_HOME}
ENV HADOOP_CONF_DIR     ${HADOOP_HOME}/etc/hadoop 
ENV HADOOP_LOG_DIR      /var/log/hdfs
ENV HADOOP_TMP_DIR      /hadoop
ENV YARN_CONF_DIR       ${HADOOP_HOME}/etc/hadoop
ENV YARN_HOME           ${HADOOP_HOME}
ENV YARN_LOG_DIR        /var/log/yarn

ENV JAVA_HOME   /usr/lib/jvm/default-jvm
ENV PATH        $PATH:${JAVA_HOME}/bin:${HADOOP_HOME}/sbin:${HADOOP_HOME}/bin

ENV HADOOP_CLUSTER_NAME       hadoop
ENV HADOOP_ZOOKEEPER_QUORUM   zookeeper-1.vnet:2181,zookeeper-2.vnet:2181,zookeeper-3.vnet:2181
ENV HADOOP_NAMENODE1_HOSTNAME namenode-1.vnet
ENV HADOOP_NAMENODE2_HOSTNAME namenode-2.vnet
ENV HADOOP_QJOURNAL_ADDRESS   journalnode-1.vnet:8485;journalnode-2.vnet:8485;journalnode-3.vnet:8485
ENV HADOOP_DFS_REPLICATION    3
ENV YARN_RESOURCEMANAGER_HOSTNAME resourcemanager-1.vnet
ENV MAPRED_JOBHISTORY_HOSTNAME    historyserver-1.vnet

# [Java 8] Over usage of virtual memory(https://issues.apache.org/jira/browse/YARN-4714)
# ENV MAPRED_CHILD_JAVA_OPTS "-XX:ReservedCodeCacheSize=100M -XX:MaxMetaspaceSize=256m -XX:CompressedClassSpaceSize=256m"

## default memory/cpu setting
ENV HADOOP_HEAPSIZE              1000
ENV YARN_HEAPSIZE                1000
ENV YARN_NODEMANAGER_MEMORY_MB   8192
ENV YARN_NODEMANAGER_CPU_VCORES  8
ENV YARN_NODEMANAGER_VMEM_CHECK  true
ENV YARN_SCHEDULER_MIN_ALLOC_MB  1024
ENV YARN_APPMASTER_MEMORY_MB     1536
ENV YARN_APPMASTER_COMMAND_OPTS  -Xmx1024m
ENV MAPRED_MAP_MEMORY_MB         1024
ENV MAPRED_REDUCE_MEMORY_MB      1024

## HDFS path
ENV YARN_REMOTE_APP_LOG_DIR      /tmp/logs
ENV YARN_APP_MAPRED_STAGING_DIR  /tmp/hadoop-yarn/staging

ENV PROTOBUF_VERSION     2.5.0
ENV GOOGLETEST_VERSION   1.5.0    

RUN set -x \
    && apk --no-cache add \
        bash \
        openjdk8-jre \
        su-exec \
        tar \
        wget \
    ## Build Protobuf
    ## - dependency lib
    && apk --no-cache add \
        zlib \
    && apk --no-cache add --virtual .builddeps \
        autoconf \
        automake \
        build-base \
        libtool \
        zlib-dev \
    # - protobuf src
    && wget -q -O - https://github.com/google/protobuf/archive/v${PROTOBUF_VERSION}.tar.gz \
        | tar -xzf - -C /tmp \
    && cd /tmp/protobuf-* \
    # - gtest src
    && wget -q -O - https://github.com/google/googletest/archive/release-${GOOGLETEST_VERSION}.tar.gz \
        | tar -xzf - \
    && mv googletest-* gtest \
    # - build
    && ./autogen.sh \
    && CXXFLAGS="$CXXFLAGS -fno-delete-null-pointer-checks" ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make \
    && make check \
    && make install \
    && rm -rf /tmp/protobuf-* \

    ## Build Hadoop
    ## - dependency lib 
    && apk --no-cache add \
        bash \
        bzip2 \
        fts \
        fuse \
        libressl-dev \
        libtirpc \
        snappy \
        zlib \
    && apk --no-cache add --virtual .builddeps.1 \
        autoconf \
        automake \
        build-base \
        bzip2-dev \
        cmake \
        curl \
        fts-dev \
        fuse-dev \
        git \
        libtirpc-dev \
        libtool \
        maven \
        openjdk8 \
        snappy-dev \
        zlib-dev \
    ## - hadoop src
    && mirror_url=$( \
        wget -q -O - "http://www.apache.org/dyn/closer.cgi/?as_json=1" \
        | grep "preferred" \
        | sed -n 's#.*"\(http://*[^"]*\)".*#\1#p' \
        ) \
    && wget -q -O - ${mirror_url}/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-src.tar.gz \
        | tar -xzf - -C /tmp \

    && cd /tmp/hadoop-* \
    ## - bad substitution at line 11
    && sed -ri 's/executable="sh"/executable="bash"/g' hadoop-project-dist/pom.xml \
    ## - error: 'sys_nerr' undeclared (first use in this function)
    && sed -ri 's/^#if defined\(__sun\)/#if 1/g' hadoop-common-project/hadoop-common/src/main/native/src/exception.c \
    ## - error: undefined reference to fts_* 
    && sed -ri 's/^( *container)/\1\n    fts/g' hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager/src/CMakeLists.txt \
    ## - warning: implicit declaration of function 'setnetgrent'
    && sed -ri 's/^(.*JniBasedUnixGroupsNetgroupMapping.c)/#\1/g' hadoop-common-project/hadoop-common/src/CMakeLists.txt \
    ## - fatal error: rpc/types.h: No such file or directory
    && sed -ri 's#^(include_directories.*)#\1\n    /usr/include/tirpc#' hadoop-tools/hadoop-pipes/src/CMakeLists.txt \
    && sed -ri 's/^( *pthread)/\1\n    tirpc/g' hadoop-tools/hadoop-pipes/src/CMakeLists.txt \
    ## - build
    && mvn package -Pdist,native -DskipTests -DskipDocs -Dtar \
#    && mv hadoop-dist/target/hadoop-${HADOOP_VERSION} /usr/local/ \
    && mv hadoop-dist/target/hadoop-${HADOOP_VERSION}.tar.gz / \
    && tar -xzf /hadoop-${HADOOP_VERSION}.tar.gz -C /usr/local \
    && rm -rf /tmp/hadoop-* \
    && cd / \

    # # download hadoop-bin
    # && set -x \
    # && mirror_url=$( \
    #     wget -q -O - http://www.apache.org/dyn/closer.cgi/hadoop/common/ \
    #     | sed -n 's#.*href="\(http://ftp.[^"]*\)".*#\1#p' \
    #     | head -n 1 \
    # ) \
    # && wget -q -O - ${mirror_url}/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    #    | tar -xzf - -C /usr/local \
    && ln -s /usr/local/hadoop-${HADOOP_VERSION} /usr/local/hadoop-${HADOOP_VERSION%.*} \
    && env \
       | grep -E '^(JAVA|HADOOP|PATH|YARN)' \
       | sed 's/^/export /g' \
       > ~/.profile \
    && cp ~/.profile /etc/profile.d/hadoop \
    && sed -i 's@${JAVA_HOME}@'${JAVA_HOME}'@g' ${HADOOP_CONF_DIR}/hadoop-env.sh \     
    # user/dir/permission
    && adduser -D -g '' -s /sbin/nologin -u 1000 docker \
    && for user in hadoop hdfs yarn mapred hbase; do \
         adduser -D -g '' -s /sbin/nologin ${user}; \
       done \
    && for user in root hdfs yarn mapred hbase docker; do \
         adduser ${user} hadoop; \
       done \      
    && mkdir -p \
        ${HADOOP_TMP_DIR}/dfs \
        ${HADOOP_TMP_DIR}/yarn \
        ${HADOOP_TMP_DIR}/mapred \
        ${HADOOP_TMP_DIR}/nm-local-dir \
        ${HADOOP_TMP_DIR}/yarn-nm-recovery \
        ${HADOOP_LOG_DIR} \
        ${YARN_LOG_DIR} \       
    && chmod -R 775 \
        ${HADOOP_LOG_DIR} \
        ${YARN_LOG_DIR} \
    && chmod -R 700 ${HADOOP_TMP_DIR}/dfs \
    && chown -R hdfs:hadoop \
        ${HADOOP_TMP_DIR}/dfs \
        ${HADOOP_LOG_DIR} \
    && chown -R yarn:hadoop \
        ${HADOOP_TMP_DIR}/yarn \
        ${HADOOP_TMP_DIR}/nm-local-dir \
        ${HADOOP_TMP_DIR}/yarn-nm-recovery \
        ${YARN_LOG_DIR} \
    && chown -R mapred:hadoop \
        ${HADOOP_TMP_DIR}/mapred  \
    # cleanup
    # - remove unnecessary doc/src files 
    && rm -rf ${HADOOP_HOME}/share/doc \
    && for dir in common hdfs mapreduce tools yarn; do \
         rm -rf ${HADOOP_HOME}/share/hadoop/${dir}/sources; \
       done \
    && rm -rf ${HADOOP_HOME}/share/hadoop/common/jdiff \
    && rm -rf ${HADOOP_HOME}/share/hadoop/mapreduce/lib-examples \
    && rm -rf ${HADOOP_HOME}/share/hadoop/yarn/test \
    && find ${HADOOP_HOME}/share/hadoop -name *test*.jar | xargs rm -rf \
#    && rm -rf ${HADOOP_HOME}/lib/native \
    && rm /hadoop-${HADOOP_VERSION}.tar.gz \
    && rm -rf /root/.m2 \
    && apk del \
        .builddeps \
        .builddeps.1 \
    && echo

    
COPY etc/*  ${HADOOP_CONF_DIR}/
COPY bin/*  /usr/local/bin/
COPY lib/*  /usr/local/lib/

WORKDIR ${HADOOP_HOME}

VOLUME ["${HADOOP_TMP_DIR}", "${HADOOP_LOG_DIR}", "${YARN_LOG_DIR}", "${HADOOP_HOME}"]

ENTRYPOINT ["entrypoint.sh"]