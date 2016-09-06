
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
	docker-compose up -d
	docker run -it --rm --net vnet --volumes-from historyserver-1 smizy/hadoop-base:2.7.3-alpine  bash -c 'for i in $$(seq 80); do nc -z historyserver-1.vnet 19888 && break; echo -n .; sleep 1; done; echo'
	bats test/test_*.bats