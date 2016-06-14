export GOPATH=$(PWD)
src/ovach/y.go: 
	go tool yacc -p Ovach src/ovach/ovach.y
build: src/ovach/y.go
	go build -o bin/ovach y.go
run:
	$$GOPATH/bin/ovach
