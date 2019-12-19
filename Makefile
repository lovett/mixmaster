SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user

# Deploy the application on the production host via Ansible.
install:
	ansible-playbook ansible/install.yml

# Redeploy the application on the production host via Ansible.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Install third-party packages in the development environment.
setup:
	zef install JSON::Fast
	zef install Config::INI
	zef install Email::Simple;

reload:
	systemctl --user daemon-reload

test-gitea:
	curl -v --header "Content-Type: application/json" --data @samples/new-build.json 'http://127.0.0.1:8585/gitea'

test-adhoc:
	curl -v --header "Content-Type: application/json" --data @samples/adhoc.json 'http://127.0.0.1:8585/adhoc'

clean:
	rm -f INBOX/*
	rm -rf INPROGRESS BUILDS

journalgrep:
	journalctl --since now -f | grep mixmaster

# Perform linting of bin scripts.
check:
	perl6 -c bin/mmbridge.p6
	perl6 -c bin/mmbuild.p6

# Set up systemd services for use during development.
systemd-enable:
	ln -sf $(PWD)/services/mixmaster-inbox-watcher.path ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/services/mixmaster-inbox-watcher.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/services/mixmaster-bridge.service ${SYSTEMD_USER_DIR}
	ln -sf $(PWD)/services/mixmaster-bridge.socket ${SYSTEMD_USER_DIR}

	systemctl --user --now enable mixmaster-inbox-watcher.path
	systemctl --user --now enable mixmaster-bridge.socket

# Remove systemd services used during development.
systemd-disable:
	-systemctl --user --now --quiet disable mixmaster-inbox-watcher.path
	-systemctl --user --now --quiet disable mixmaster-bridge.socket
	rm -f ${SYSTEMD_USER_DIR}/mixmaster-inbox-watcher.service
	rm -f ${SYSTEMD_USER_DIR}/mixmaster-bridge.service
