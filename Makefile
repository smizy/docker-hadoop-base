
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
		--rm -t smizy/hadoop-base:${TAG} .
	docker images | grep hadoop-base

.PHONY: test
test:
	(docker network ls | grep vnet ) || docker network create vnet
	cat docker-compose.yml \
		| sed -e 's/HADOOP_HEAP=1000/HADOOP_HEAP=600/g' \
		> docker-compose.ci.yml.tmp
	docker-compose -f docker-compose.ci.yml.tmp up -d 
	docker run --net vnet --volumes-from historyserver-1 smizy/hadoop-base:2.7.3-alpine  bash -c 'for i in $$(seq 200); do nc -z historyserver-1.vnet 19888 && echo test starting && break; echo -n .; sleep 1; [ $$i -ge 200 ] && echo timeout && exit 124 ; done'
	bats test/test_*.bats