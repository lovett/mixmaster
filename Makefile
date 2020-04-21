# Perform linting of bin scripts.
check:
	rakudo -c bin/mmbridge
	rakudo -c bin/mmbuild
	rakudo -c bin/mmsetup

# Reset application directories.
clean:
	rm -rf ~/Builds/*
	rm -rf /var/spool/mixmaster/$(USER)/*.ini

# Deploy the application to the production.
install:
	ansible-playbook ansible/install.yml

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
