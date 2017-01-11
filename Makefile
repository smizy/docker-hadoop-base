
.PHONY: all
all: runtime

.PHONY: clean
clean:
	docker rmi -f smizy/hadoop-base:${TAG} || :

.PHONY: runtime
runtime:
	docker build \
		--build-arg BUILD_DATE=${BUILD_DATE} \
		--build-arg VCS_REF=${VCS_REF} \
		--build-arg VERSION=${VERSION} \
		-t smizy/hadoop-base:${TAG} .
	docker images | grep hadoop-base

.PHONY: test
test:
	(docker network ls | grep vnet ) || docker network create vnet
	zookeeper=1 namenode=1 datanode=1 ./make_docker_compose_file.sh hdfs yarn \
		| sed -E 's/(HADOOP|YARN)_HEAPSIZE=1000/\1_HEAPSIZE=600/g' \
		| sed -e 's/Xmx1024m/Xmx512m/g' \
		> docker-compose.ci.yml.tmp
	docker-compose -f docker-compose.ci.yml.tmp up -d 
	docker run --net vnet --volumes-from historyserver-1 smizy/hadoop-base:${VERSION}-alpine  bash -c 'for i in $$(seq 200); do nc -z historyserver-1.vnet 19888 && echo test starting && break; echo -n .; sleep 1; [ $$i -ge 200 ] && echo timeout && exit 124 ; done'
	bats test/test_*.bats
	docker-compose -f docker-compose.ci.yml.tmp stop
