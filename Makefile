LOCAL_BIN := /usr/local/bin
LOCAL_SHARE := /usr/local/share/mixmaster

# Perform linting of bin scripts.
check:
	rakudo -c bin/mmbridge
	rakudo -c bin/mmbuild
	rakudo -c bin/mmsetup

# Reset application directories.
clean:
	rm -rf ~/Builds/*
	rm -rf /var/spool/mixmaster/$(USER)/*.ini

# Install application scripts.
install:
	sudo cp bin/mmsetup  $(LOCAL_BIN)/mmsetup
	sudo cp bin/mmbuild  $(LOCAL_BIN)/mmbuild
	sudo cp bin/mmbridge $(LOCAL_BIN)/mmbridge
	sudo mkdir -p $(LOCAL_SHARE)
	sudo cp -r lib $(LOCAL_SHARE)/lib

# Install application libraries.
# Anything listed here should also be in ansible/install.yml.
setup:
	zef install JSON::Fast
	zef install Config::INI
	zef install Email::Simple;

# Simulate a Gitea request without using systemd.
test-gitea: clean
	./bin/mmbridge < samples/gitea.http
	cat Builds/INBOX/*

# Update the current installation on the production host.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Reverse of install.
uninstall:
	sudo rm -f $(LOCAL_BIN)/mmsetup
	sudo rm -f $(LOCAL_BIN)/mmbuild
	sudo rm -f $(LOCAL_BIN)/mbridge
	sudo rm -rf $(LOCAL_SHARE)
