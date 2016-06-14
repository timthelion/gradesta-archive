export GOPATH=$(PWD)
dependencies:
	go get gopkg.in/readline.v1
src/ovach/y.go: 
	go tool yacc -p Ovach src/ovach/ovach.y
build: src/ovach/y.go
	go build -o bin/ovach y.go
try: build
	$$GOPATH/bin/ovach
run:
	$$GOPATH/bin/ovach
