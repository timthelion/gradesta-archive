mge: mge.tg
	echo "#!/usr/bin/python3" > mge
	./tgcat mge.tg --prepend-street-names --comment-prefix=\ \# --no-follow-prefix=x >> mge
	chmod +x ./mge

all: mge
