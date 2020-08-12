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

# Install the application on a remote machine.
deploy:
	ansible-playbook ansible/install.yml

# Install the application on the local machine.
install:
	sudo mkdir -p $(LOCAL_BIN)
	sudo mkdir -p $(LOCAL_SHARE)
	sudo rsync -a bin/ $(LOCAL_BIN)
	sudo rsync -a --delete lib/ $(LOCAL_SHARE)/lib

# Install third-party libraries.
# Anything listed here should also be in ansible/install.yml.
setup:
	sudo zef install JSON::Fast Config::INI Email::Simple

# Simulate a Gitea request without using systemd.
test-gitea: clean
	./bin/mmbridge < samples/gitea.http
	cat Builds/INBOX/*

# Update the current installation on a remote host.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Reverse of install.
uninstall:
	sudo rm -f $(LOCAL_BIN)/mmsetup
	sudo rm -f $(LOCAL_BIN)/mmbuild
	sudo rm -f $(LOCAL_BIN)/mbridge
	sudo rm -rf $(LOCAL_SHARE)

# Perform a local installation whenever application files change.
watch:
	find lib bin -type f -name 'mm*' -or -name '*.pm6' | entr make install

# Push the repository to GitHub.
mirror:
	git push --force git@github.com:lovett/mixmaster.git master:master
