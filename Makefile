install: uninstall
	zef --to=home install .

uninstall:
	zef uninstall Mixmaster || true

mirror:
	git push --force git@github.com:lovett/mixmaster.git master:master
