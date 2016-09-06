
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
	sleep 60
	bats test/test_*.bats