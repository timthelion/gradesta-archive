pycfg: pycfg.tg
	echo \#\!/usr/bin/python3 > .pycfg
	tgtemplate pycfg.tg --comment-prefix=\ \# >> .pycfg
	mv .pycfg pycfg
	chmod +x ./pycfg

mge: mge.tg
	echo \#\!/usr/bin/python3 > mge
	tgtemplate mge.tg --comment-prefix=\ \# >> mge
	chmod +x ./mge

mge-debug: mge.tg
	echo \#\!/usr/bin/python3 > mge-debug
	tgtemplate mge.tg --comment-prefix=\ \# >> mge-debug
	chmod +x ./mge-debug

all: mge pycfg
