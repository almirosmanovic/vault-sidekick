
NAME=vault-sidekick
AUTHOR ?= ukhomeofficedigital
REGISTRY ?= quay.io
GOVERSION ?= 1.7.1
HARDWARE=$(shell uname -m)
VERSION=$(shell awk '/Version =/ { print $$3 }' main.go | sed 's/"//g')
VETARGS?=-asmdecl -atomic -bool -buildtags -copylocks -methods -nilfunc -printf -rangeloops -shift -structtags -unsafeptr

.PHONY: test authors changelog build docker static release

default: build

build: deps
	@echo "--> Compiling the project"
	mkdir -p bin
	godep go build -o bin/${NAME}

static: deps
	@echo "--> Compiling the static binary"
	mkdir -p bin
	CGO_ENABLED=0 GOOS=linux godep go build -a -tags netgo -ldflags '-w' -o bin/${NAME}

docker-build:
	@echo "--> Compiling the project"
	${SUDO} docker run --rm \
		-v ${PWD}:/go/src/github.com/UKHomeOffice/${NAME} \
		-w /go/src/github.com/UKHomeOffice/${NAME} \
		-e GOOS=linux \
		golang:${GOVERSION} \
		make static

docker: static
	@echo "--> Building the docker image"
	docker build -t ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} .

push: docker
	@echo "--> Pushing the image to docker.io"
	docker push ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION}

release: static
	mkdir -p release
	gzip -c bin/${NAME} > release/${NAME}_${VERSION}_linux_${HARDWARE}.gz
	rm -f release/${NAME}

clean:
	rm -rf ./bin 2>/dev/null
	rm -rf ./release 2>/dev/null

authors:
	@echo "--> Updating the AUTHORS"
	git log --format='%aN <%aE>' | sort -u > AUTHORS

deps:
	@echo "--> Installing build dependencies"
	@go get github.com/tools/godep

vet:
	@echo "--> Running go tool vet $(VETARGS) ."
	@go tool vet 2>/dev/null ; if [ $$? -eq 3 ]; then \
		go get golang.org/x/tools/cmd/vet; \
	fi
	@go tool vet $(VETARGS) .

format:
	@echo "--> Running go fmt"
	@go fmt $(PACKAGES)

gofmt:
	@echo "--> Running gofmt check"
	@gofmt -s -l *.go \
      | grep -q \.go ; if [ $$? -eq 0 ]; then \
            echo "You need to runn the make format, we have file unformatted"; \
            gofmt -s -l *.go; \
            exit 1; \
      fi
cover:
	@echo "--> Running go cover"
	@godep go test --cover

test: deps
	@echo "--> Running the tests"
	go test -v
	@$(MAKE) gofmt
	@$(MAKE) vet

changelog: release
	git log $(shell git tag | tail -n1)..HEAD --no-merges --format=%B > changelog
