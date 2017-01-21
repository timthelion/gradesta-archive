#!/usr/bin/make
tg2maketargets:tg2maketargets.tg pycfg
	tgtemplate tg2maketargets.tg --comment-prefix=\ \# --dont-comment-square-zero > tg2maketargets
	chmod +x ./tg2maketargets

pycfg:pycfg.tg
	tgtemplate pycfg.tg --comment-prefix=\ \# --dont-comment-square-zero > .pycfg
	mv .pycfg pycfg
	chmod +x ./pycfg

mge:pycfg mge.tg
	tgtemplate mge.tg --comment-prefix=\ \# --dont-comment-square-zero > mge
	chmod +x ./mge

mge-debug:pycfg mge.tg
	tgtemplate mge.tg --comment-prefix=\ \# --dont-comment-square-zero > mge-debug
	chmod +x ./mge-debug

all:tg2maketargets pycfg mge
	

