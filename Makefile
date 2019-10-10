SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user
PERL6LIB := inst\#modules

install: systemd-enable
	zef -to=$(PERL6LIB) install JSON::Fast
	zef -to=$(PERL6LIB) install Config::INI

uninstall: systemd-disable

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

systemd-enable:
	ln -sf $(PWD)/systemd/mixmaster-inbox-watcher.path ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-inbox-watcher.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge@.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge.socket ${SYSTEMD_USER_DIR}
	systemctl --user --now enable mixmaster-inbox-watcher.path
	systemctl --user --now enable mixmaster-gitea-bridge.socket

systemd-disable:
	-systemctl --user --now --quiet disable mixmaster-inbox-watcher.path
	-systemctl --user --now --quiet disable mixmaster-gitea-bridge.socket
	rm -f ${SYSTEMD_USER_DIR}/mixmaster-inbox-watcher.service
	rm -f ${SYSTEMD_USER_DIR}/systemd/mixmaster-gitea-bridge@.service
