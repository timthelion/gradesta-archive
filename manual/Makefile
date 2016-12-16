all: book.texi
	./gendocs.sh --no-ascii --split section --email timothy@hobbs.cz book "TEXTGRAPH MANUAL - Extended Manual to the textgraph Ecosystem"
	sed -i 's/rose.png\" alt/rose.png\" width="20%" alt/g' manual/book.html manual/html_section/*.html
	sed -i 's/torus.png\" alt/torus.png\" width="40%" alt/g' manual/book.html manual/html_section/*.html
	sed -i 's/stalactites.jpg\" alt/stalactites.jpg\" width="40%" alt/g' manual/book.html manual/html_section/*.html
	sed -i 's/ice-crystals.jpg\" alt/ice-crystals.jpg\" width="40%" alt/g' manual/book.html manual/html_section/*.html
	sed -i 's/.png\" alt/.png\" width="60%" alt/g' manual/book.html manual/html_section/*.html
	sed -i 's/.jpg\" alt/.jpg\" width="60%" alt/g' manual/book.html manual/html_section/*.html
