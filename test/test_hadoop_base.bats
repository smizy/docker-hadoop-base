load test_helper

@test "hdfs is the correct version" {
  run docker run --volumes-from datanode-1 smizy/hadoop-base:${VERSION}-alpine hdfs version
  [ $status -eq 0 ]
  [ "${lines[0]}" = "Hadoop ${VERSION}" ]
}

@test "hadoop pi calc test" {
  run docker run --net vnet --volumes-from datanode-1 -e HADOOP_HEAPSIZE=600 smizy/hadoop-base:${VERSION}-alpine hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-${VERSION}.jar pi 10 100
  echo "${output}"

  [ $status -eq 0 ]
}

