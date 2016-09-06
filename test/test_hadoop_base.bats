load test_helper

@test "hadoop pi calc test" {
  run docker run --net vnet --volumes-from datanode-1 smizy/hadoop-base:${VERSION}-alpine hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar pi 10 10
  echo "${output}"

  [ $status -eq 0 ]
}

