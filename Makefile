BIN_IMAGE = blockbook-build
DEB_IMAGE = blockbook-build-deb
PACKAGER = $(shell id -u):$(shell id -g)
NO_CACHE = false
UPDATE_VENDOR = 1
ARGS ?=

TARGETS=$(subst .json,, $(shell ls configs/coins))

DOCKER_NS="registry.inbitcoin.it/inbitcoin"
VERSION=$(shell jq -r '.version' configs/environ.json)
SHA1=$(shell git rev-parse HEAD | cut -c 1-8)

.PHONY: build build-debug test deb docker build-deb build-docker version help

default: help

build: .bin-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" -v "$(CURDIR)/build:/out" $(BIN_IMAGE) make build ARGS="$(ARGS)"

build-debug: .bin-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" -v "$(CURDIR)/build:/out" $(BIN_IMAGE) make build-debug ARGS="$(ARGS)"

test: .bin-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" --network="host" $(BIN_IMAGE) make test ARGS="$(ARGS)"

test-integration: .bin-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" --network="host" $(BIN_IMAGE) make test-integration ARGS="$(ARGS)"

test-all: .bin-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" --network="host" $(BIN_IMAGE) make test-all ARGS="$(ARGS)"

deb-backend-%: .deb-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" -v "$(CURDIR)/build:/out" $(DEB_IMAGE) /build/build-deb.sh backend $* $(ARGS)

deb-blockbook-%: .deb-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" -v "$(CURDIR)/build:/out" $(DEB_IMAGE) /build/build-deb.sh blockbook $* $(ARGS)

deb-%: .deb-image
	docker run -t --rm -e PACKAGER=$(PACKAGER) -e UPDATE_VENDOR=$(UPDATE_VENDOR) -v "$(CURDIR):/src" -v "$(CURDIR)/build:/out" $(DEB_IMAGE) /build/build-deb.sh all $* $(ARGS)

deb-blockbook-all: clean-deb $(addprefix deb-blockbook-, $(TARGETS))

$(addprefix all-, $(TARGETS)): all-%: clean-deb build-images deb-%

all: clean-deb build-images $(addprefix deb-, $(TARGETS))

build-images: clean-images
	$(MAKE) .bin-image .deb-image

.bin-image:
	@if [ $$(build/tools/image_status.sh $(BIN_IMAGE):latest build/docker) != "ok" ]; then \
		echo "Building image $(BIN_IMAGE)..."; \
		docker build --no-cache=$(NO_CACHE) -t $(BIN_IMAGE) -f build/docker/bin/Dockerfile .; \
	else \
		echo "Image $(BIN_IMAGE) is up to date"; \
	fi

.deb-image: .bin-image
	@if [ $$(build/tools/image_status.sh $(DEB_IMAGE):latest build/docker) != "ok" ]; then \
		echo "Building image $(DEB_IMAGE)..."; \
		docker build --no-cache=$(NO_CACHE) -t $(DEB_IMAGE) build/docker/deb; \
	else \
		echo "Image $(DEB_IMAGE) is up to date"; \
	fi

clean: clean-bin clean-deb

clean-all: clean clean-images

clean-bin:
	find build -maxdepth 1 -type f -executable -delete

clean-deb:
	rm -rf build/pkg-defs
	rm -f build/*.deb

clean-images: clean-bin-image clean-deb-image
	rm -f .bin-image .deb-image  # remove obsolete tag files

clean-bin-image:
	- docker rmi $(BIN_IMAGE)

clean-deb-image:
	- docker rmi $(DEB_IMAGE)

docker: all-bitcoin build-docker

build-deb: all-bitcoin

build-docker:
	docker build -t $(DOCKER_NS)/blockbook:$(VERSION)_$(SHA1) .

version:
	@echo $(VERSION)

help:
	@ echo "Usage: make [target]\n"
	@ echo "Targets:"
	@ echo " - docker:         builds a docker image of this project (warn: cleans cache each time)"
	@ echo " - build-deb:      builds only debian packages"
	@ echo " - build-docker:   builds only docker image"
	@ echo " - version:        shows project version"
	@ echo " - help:           shows this message"
	@ echo ""
	@ echo "Other upstream targets are available, here undocumented"
	@ echo "\nDefault: help"
