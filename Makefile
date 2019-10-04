SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user
PERL6LIB := inst\#modules

install:
	ln -sf $(PWD)/systemd/mixmaster.path ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge@.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge.socket ${SYSTEMD_USER_DIR}
	systemctl --user --now enable mixmaster.path
	systemctl --user --now enable mixmaster-gitea-bridge.socket
	zef -to=$(PERL6LIB) install JSON::Fast
	zef -to=$(PERL6LIB) install Config::INI

reload:
	systemctl --user daemon-reload

test:
	curl -v --header "Content-Type: application/json" --data @samples/new-build.json 'http://127.0.0.1:8585'

clean:
	rm -f INBOX/*
	rm -rf INPROGRESS BUILDS

journalgrep:
	journalctl --since now -f | grep mixmaster.p6

check:
	perl6 -I $(PERL6LIB) -c bin/gitea-bridge.p6
	perl6 -I $(PERL6LIB) -c bin/mixmaster.p6
