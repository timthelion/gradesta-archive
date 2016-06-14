export GOPATH=$(PWD)
dependencies:
	go get gopkg.in/readline.v1
build/y.go: src/ovach/ovach.y
	mkdir -p build
	cd build ; go tool yacc -p Ovach ../src/ovach/ovach.y
build: build/y.go
	go build -o bin/ovach build/y.go
try: build
	$$GOPATH/bin/ovach
run:
	$$GOPATH/bin/ovach
