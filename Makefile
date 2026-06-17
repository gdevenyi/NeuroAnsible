ANSIBLE_TAGS?=--skip-tags resources

.PHONY: help build run shell vm-test test-all

help:
	@echo "NeuroAnsible Docker"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build Docker image (skip resources by default)"
	@echo "  run       - Run container (interactive shell)"
	@echo "  shell     - Open shell in running container"
	@echo "  vm-test   - Run deploy.yml in a libvirt VM (DISTRO=24.04)"
	@echo "  test-all  - Test across Ubuntu 22.04/24.04/26.04 VMs"
	@echo "  help      - Show this help (default)"
	@echo ""
	@echo "ANSIBLE_TAGS passthrough:"
	@echo "  make build ANSIBLE_TAGS=\"--tags freesurfer\""
	@echo "  make build ANSIBLE_TAGS=\"--tags ants --tags matlab-runtime\""
	@echo "  make build ANSIBLE_TAGS=\"\"                          # build everything"

build:
	docker build \
		--build-arg ANSIBLE_TAGS="$(ANSIBLE_TAGS)" \
		-t neuroansible:deployed .

run:
	docker run --rm -it neuroansible:deployed

shell:
	@if [ -z "$$(docker ps -q -f ancestor=neuroansible:deployed)" ]; then \
		echo "No container running. Start one with 'make run'"; \
	else \
		docker exec -it $$(docker ps -q -f ancestor=neuroansible:deployed) bash; \
	fi

# Libvirt VM testing (see testing/libvirt/). Pass DISTRO=22.04|24.04|26.04.
vm-test:
	$(MAKE) -C testing/libvirt vm-up vm-snapshot vm-test $(if $(DISTRO),DISTRO=$(DISTRO),)

test-all:
	$(MAKE) -C testing/libvirt test-all
