TAG ?= dev
VERSION ?= master
NAMESPACE ?= kernelits
IMAGE ?= niobiocash-walletd
CONTAINER ?= nbr-walletd

.PHONY: build push shell run start stop rm release 

build: Dockerfile
	docker build --no-cache --build-arg VERSION=$(VERSION) -t $(NAMESPACE)/$(IMAGE):$(TAG) -f Dockerfile .

push:
	docker push $(NAMESPACE)/$(IMAGE):$(TAG)

shell:
	docker run --rm --name $(CONTAINER) -i -t $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(TAG) /bin/bash

run:
	docker run --rm --name $(CONTAINER) $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(TAG)

start:
	docker run -d --name $(CONTAINER) $(PORTS) $(VOLUMES) $(ENV) $(NAMESPACE)/$(IMAGE):$(TAG)

stop:
	docker stop $(CONTAINER)

rm:
	docker rm $(CONTAINER)

default: build
