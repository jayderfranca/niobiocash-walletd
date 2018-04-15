VERSION ?= dev
NAMESPACE ?= kernelits
IMAGE ?= niobiocash-walletd
CONTAINER ?= nbr-walletd

.PHONY: build push shell run start stop rm release 

build: Dockerfile
	docker build --no-cache -t $(NAMESPACE)/$(IMAGE):$(VERSION) -f Dockerfile .

push:
	docker push $(NAMESPACE)/$(IMAGE):$(VERSION)

shell:
	docker run --rm --name $(CONTAINER) -i -t $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(VERSION) /bin/bash

run:
	docker run --rm --name $(CONTAINER) $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(VERSION)

start:
	docker run -d --name $(CONTAINER) $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(VERSION)

stop:
	docker stop $(CONTAINER)

rm:
	docker rm $(CONTAINER)

release: build
	make push -e VERSION=$(VERSION)

default: build
