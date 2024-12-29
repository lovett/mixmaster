install: uninstall
	zef --to=home install .

uninstall:
	zef uninstall Mixmaster || true

setup:
	zef --to=home --deps-only install .

test:
	prove6 --lib t/

mirror:
	git push --force git@github.com:lovett/mixmaster.git master:master
