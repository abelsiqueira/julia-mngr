install:
	cp -f julia-mngr.sh /usr/local/bin/julia-mngr
	julia-mngr install

uninstall:
	rm -f /usr/local/bin/julia-mngr
