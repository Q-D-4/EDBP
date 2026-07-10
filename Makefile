.PHONY: init prepare build clean verify test

#################################
# Initialize Build Environment
#################################
init:
	lb config

#################################
# Prepare Build Files
#################################
prepare:
	@echo "[EDBP] Preparing build environment..."
	@if [ ! -f VERSION ]; then \
		echo "2.0.1" > VERSION; \
	fi
	@if [ ! -f config/includes.chroot/etc/edbp/keys/devops_admin.pub ]; then \
		echo "ERROR: Missing SSH public key"; \
		exit 1; \
	fi

#################################
# Build ISO
#################################
build: prepare
	@echo "[EDBP] Starting ISO Build..."
	sudo lb build

#################################
# Clean Workspace
#################################
clean:
	@echo "[EDBP] Cleaning build environment..."
	sudo lb clean --purge
	#sudo rm -rf cache/*
	sudo rm -rf chroot/*
	sudo rm -rf binary/*

#################################
# Security Verification
#################################
verify:
	@echo "[EDBP] Running security checks..."
	@if find . -name "*.pem" -o -name "id_rsa" | grep .; then \
		echo "ERROR: Private key detected"; \
		exit 1; \
	fi
	@if grep -r "password" config/ | grep -v crypted; then \
		echo "WARNING: Possible plain password"; \
	fi
	ssh-keygen -lf config/includes.chroot/etc/edbp/keys/devops_admin.pub
	@echo "Security checks completed."

#################################
# ISO Testing
#################################
test:
	@echo "[EDBP] ISO Test Ready"
	qemu-system-x86_64 \
	-m 4096 \
	-cdrom *.iso \
	-boot d
