# Default Ansible tags (skip resources to keep image size ~20GB)
ANSIBLE_TAGS?=--skip-tags resources

.PHONY: help build run shell clean freesurfer ants matlab resources test

help:
	@echo "NeuroAnsible Docker - Quick Start"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build Docker image with Ansible deployment"
	@echo "  freesurfer - Build image with only FreeSurfer (fast test)"
	@echo "  ants      - Build image with only ANTs"
	@echo "  matlab    - Build image with only MATLAB runtime and modules"
	@echo "  resources - Build image with only resources data"
	@echo "  test TAG  - Build image with custom tags (e.g., make test TAG='--tags freesurfer')"
	@echo "  run       - Run container (interactive shell)"
	@echo "  shell     - Open shell in running container"
	@echo "  clean     - Remove Docker build cache and images"
	@echo ""
	@echo "Quick start:"
	@echo "  make build       # Build the image (~20GB, ~30 min)"
	@echo "  make freesurfer  # Test just FreeSurfer (~6GB, ~10 min)"
	@echo "  make run         # Run the container"

# Standard build with configurable tags
build:
	docker build --build-arg ANSIBLE_TAGS="$(ANSIBLE_TAGS)" -t neuroansible:deployed .
	@echo "✓ Image built successfully with tags: $(ANSIBLE_TAGS)"
	@echo "Run 'make run' to start the container"

# Tag-based build targets for testing specific software
freesurfer:
	docker build --build-arg ANSIBLE_TAGS="--tags freesurfer" -t neuroansible:freesurfer .
	@echo "✓ FreeSurfer image built successfully"
	@echo "Run 'docker run --rm -it neuroansible:freesurfer' to test"
	@echo "Verify: ls -la /opt/quarantine/software/freesurfer/7.4.1/install/"

ants:
	docker build --build-arg ANSIBLE_TAGS="--tags ants" -t neuroansible:ants .
	@echo "✓ ANTs image built successfully"
	@echo "Run 'docker run --rm -it neuroansible:ants' to test"

matlab:
	docker build --build-arg ANSIBLE_TAGS="--tags matlab-runtime --tags matlab-modules" -t neuroansible:matlab .
	@echo "✓ MATLAB image built successfully"
	@echo "Run 'docker run --rm -it neuroansible:matlab' to test"

resources:
	docker build --build-arg ANSIBLE_TAGS="--tags resources" -t neuroansible:resources .
	@echo "✓ Resources image built successfully"
	@echo "Run 'docker run --rm -it neuroansible:resources' to test"

# Custom tag-based build for testing
test:
	docker build --build-arg ANSIBLE_TAGS="$(TAG)" -t neuroansible:test .
	@echo "✓ Test image built successfully with tags: $(TAG)"
	@echo "Run 'docker run --rm -it neuroansible:test' to test"

run:
	docker run --rm -it neuroansible:deployed

shell:
	@if [ -z "$$(docker ps -q -f ancestor=neuroansible:deployed)" ]; then \
		echo "No container running. Start one with 'make run'"; \
	else \
		docker exec -it $$(docker ps -q -f ancestor=neuroansible:deployed) bash; \
	fi

clean:
	docker system prune -f
	docker rmi neuroansible:deployed neuroansible:freesurfer neuroansible:ants neuroansible:matlab neuroansible:resources neuroansible:test 2>/dev/null || true
	@echo "✓ Cleanup completed"
