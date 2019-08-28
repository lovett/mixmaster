SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user
PERL6LIB := inst\#modules

install:
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge@.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/systemd/mixmaster-gitea-bridge.socket ${SYSTEMD_USER_DIR}
	systemctl --user --now enable mixmaster-gitea-bridge.socket
	zef -to=$(PERL6LIB) install JSON::Fast
	zef -to=$(PERL6LIB) install Config::INI
