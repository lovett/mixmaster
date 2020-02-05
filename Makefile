# Deploy the application on the production host via Ansible.
install:
	ansible-playbook ansible/install.yml

# Redeploy the application on the production host via Ansible.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Establish a development environment.
setup:
	zef install JSON::Fast
	zef install Config::INI
	zef install Email::Simple;

# Simulate a Gitea request without using systemd.
test-gitea: clean
	./bin/mmbridge < samples/gitea.http
	cat Builds/INBOX/*

# Simulate a default request without using systemd.
test-default: clean
	./bin/mmbridge < samples/default.http

# Simulate a freestyle request without using systemd.
test-freestyle: clean
	./bin/mmbridge < samples/freestyle.http

test-get:
	./bin/mmbridge < samples/get.http

test-version:
	./bin/mmbridge < samples/version.http

# Reset the Builds directory to a pristine state.
clean:
	rm -rf ~/Builds/INBOX/*
	rm -rf ~/Builds/[a-z]*

# Perform linting of bin scripts.
check:
	perl6 -c bin/mmbridge
	perl6 -c bin/mmbuild
