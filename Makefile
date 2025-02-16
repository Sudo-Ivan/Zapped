.PHONY: all build run clean docker docker-privacy podman podman-privacy test safe help interactive certbot-image generate-certs

# Container engine selection
ifeq ($(ENGINE),podman)
    CONTAINER_ENGINE := podman
else ifeq ($(ENGINE),docker)
    CONTAINER_ENGINE := docker
else
    ifeq ($(shell which podman 2>/dev/null),)
        ifeq ($(shell which docker 2>/dev/null),)
            $(error No container engine found. Please install docker or podman)
        else
            CONTAINER_ENGINE := docker
        endif
    else
        CONTAINER_ENGINE := podman
    endif
endif

# Build targets
docker podman:
	$(CONTAINER_ENGINE) build -t zapped .

docker-privacy podman-privacy:
	$(CONTAINER_ENGINE) build -t zapped-privacy -f Dockerfile.privacy .

# Run targets
docker-run podman-run:
	$(CONTAINER_ENGINE) run --name zapped-standard --privileged --userns=keep-id \
		-p 3000:3000 \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		zapped

docker-run-privacy podman-run-privacy:
	$(CONTAINER_ENGINE) volume create i2pd-data || true
	$(CONTAINER_ENGINE) run --name zapped-privacy --privileged --userns=keep-id \
		-p 3000:3000 \
		-p 9050:9050 \
		$(if $(USE_I2P),-p 7656:7656 -v i2pd-data:/var/lib/i2pd:Z) \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		-e USE_I2P=$(USE_I2P) \
		zapped-privacy

# Utility targets
stop:
	-$(CONTAINER_ENGINE) stop zapped-standard zapped-privacy #zapped-ssl zapped-privacy-ssl 2>/dev/null

rm:
	-$(CONTAINER_ENGINE) rm zapped-standard zapped-privacy #zapped-ssl zapped-privacy-ssl 2>/dev/null

restart: stop rm
	make $(CONTAINER_ENGINE)-run

help:
	@echo "Available targets:"
	@echo "Build targets:"
	@echo "  make docker/podman                      - Build standard image"
	@echo "  make docker-privacy/podman-privacy      - Build privacy image"
	@echo
	@echo "Run targets:"
	@echo "  make docker-run/podman-run              - Run standard container"
	@echo "  make docker-run-privacy/podman-run-privacy - Run privacy container"
	@echo
	@echo "Certificate management:"
	@echo
	@echo "Environment variables:"
	@echo "  ENGINE               - Container engine (docker/podman)"
	@echo "  DOMAIN              - Domain for SSL certificate"
	@echo "  EMAIL               - Email for SSL certificate"
	@echo "  USE_I2P             - Enable/disable I2P (true/false)" 
		zapped-certbot 