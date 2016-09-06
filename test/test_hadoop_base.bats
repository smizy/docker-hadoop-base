load test_helper

@test "hadoop pi calc test" {
  MY_COMMAND="hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-${VERSION}.jar pi 10 10"
  run sudo lxc-attach -n "$(docker inspect --format "{{.Id}}" datanode-1)" -- bash -c $MY_COMMAND

  echo "${output}"
  [ $status -eq 0 ]
}

