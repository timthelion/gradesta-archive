all: book.texi
	./gendocs.sh --no-ascii --split section --email timothy@hobbs.cz book "TEXTGRAPH MANUAL - Extended Manual to the textgraph Ecosystem"
	sed -i 's/img/img width="70%"/g' manual/book.html
