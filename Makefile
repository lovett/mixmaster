# Deploy the application to the production.
install:
	ansible-playbook ansible/install.yml

# Update the current installation on the production host.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Install application libraries.
setup:
	zef install JSON::Fast
	zef install Config::INI
	zef install Email::Simple;

# Simulate a Gitea request without using systemd.
test-gitea: clean
	./bin/mmbridge < samples/gitea.http
	cat Builds/INBOX/*

# Reset the Builds and spool directories to a pristine state.
clean:
	rm -rf ~/Builds/*
	rm -rf /var/spool/mixmaster/$(USER)/*.ini

# Perform linting of bin scripts.
check:
	rakudo -c bin/mmbridge
	rakudo -c bin/mmbuild
	rakudo -c bin/mmsetup
