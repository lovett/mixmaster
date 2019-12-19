# Deploy the application on the production host via Ansible.
install:
	ansible-playbook ansible/install.yml

# Redeploy the application on the production host via Ansible.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Establish a development environment.
setup:
	mkdir -p Builds/INBOX
	touch mixmaster.ini
	zef install JSON::Fast
	zef install Config::INI
	zef install Email::Simple;

# Simulate a Gitea request without using systemd.
test-gitea: clean
	./bin/mmbridge.p6 < samples/gitea.http
	cat Builds/INBOX/*

# Simulate an adh-hoc request without using systemd.
test-adhoc: clean
	./bin/mmbridge.p6 < samples/adhoc.http
	cat Builds/INBOX/*

# Reset the Builds directory to a pristine state.
clean:
	rm -rf Builds/INBOX/*
	rm -rf Builds/[a-z]*

# Perform linting of bin scripts.
check:
	perl6 -c bin/mmbridge.p6
	perl6 -c bin/mmbuild.p6
