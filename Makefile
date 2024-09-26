LOCAL_BIN := /usr/local/bin
LOCAL_SHARE := /usr/local/share/mixmaster

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

# Update the current installation on a remote host.
upgrade:
	ansible-playbook --skip-tags firstrun ansible/install.yml

# Push the repository to GitHub.
mirror:
	git push --force git@github.com:lovett/mixmaster.git master:master
