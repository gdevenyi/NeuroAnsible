.PHONY: help vm-test test-all

help:
	@echo "NeuroAnsible"
	@echo ""
	@echo "Targets:"
	@echo "  vm-test   - Run deploy.yml in a libvirt VM (DISTRO=24.04)"
	@echo "  test-all  - Test across Ubuntu 22.04/24.04/26.04 VMs"
	@echo "  help      - Show this help (default)"
	@echo ""
	@echo "See testing/libvirt/ for the full VM test harness."

# Libvirt VM testing (see testing/libvirt/). Pass DISTRO=22.04|24.04|26.04.
vm-test:
	$(MAKE) -C testing/libvirt vm-up vm-snapshot vm-test $(if $(DISTRO),DISTRO=$(DISTRO),)

test-all:
	$(MAKE) -C testing/libvirt test-all
