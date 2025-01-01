.PHONY: all build run clean docker docker-privacy podman podman-privacy test safe help

# Container engine selection
ifeq ($(ENGINE),podman)
    CONTAINER_ENGINE := podman
else ifeq ($(ENGINE),docker)
    CONTAINER_ENGINE := docker
else
    # Auto-detect available engine
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

# Default target
all: build

# Build the project
build:
	zig build

# Run the project in development mode
run:
	zig build run

# Build for production with safety checks
safe:
	zig build -Doptimize=ReleaseSafe

# Clean build artifacts
clean:
	rm -rf zig-cache
	rm -rf zig-out

# Build standard container image
docker:
	docker build -t zapped .

podman:
	podman build -t zapped .

# Build privacy-focused container image
docker-privacy:
	docker build -t zapped-privacy -f Dockerfile.privacy .

podman-privacy:
	podman build -t zapped-privacy -f Dockerfile.privacy .

# Run standard container
docker-run:
	docker run --name zapped-standard -p 80:3000 -p 443:3443 \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		zapped

podman-run:
	podman run --name zapped-standard --privileged --userns=keep-id \
		-p 80:3000 -p 8080:3443 \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		zapped

# Run privacy container
docker-run-privacy:
	docker volume create i2pd-data || true
	docker run --name zapped-privacy -p 80:3000 -p 443:3443 \
		-p 9050:9050 \
		$(if $(USE_I2P),-p 7656:7656 -v i2pd-data:/var/lib/i2pd) \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		-e USE_I2P=$(USE_I2P) \
		zapped-privacy

podman-run-privacy:
	podman volume create i2pd-data || true
	podman run --name zapped-privacy --privileged --userns=keep-id \
		-p 80:3000 -p 443:3443 \
		-p 9050:9050 \
		$(if $(USE_I2P),-p 7656:7656 -v i2pd-data:/var/lib/i2pd:Z) \
		-e HOST=0.0.0.0 \
		-e PORT=3000 \
		-e USE_I2P=$(USE_I2P) \
		zapped-privacy

# Run with SSL
docker-run-ssl:
	docker run --name zapped-ssl -p 80:3000 -p 443:3443 \
		-e HOST=0.0.0.0 \
		-e PORT=3443 \
		-e USE_SSL=true \
		-e DOMAIN=${DOMAIN} \
		-e EMAIL=${EMAIL} \
		zapped-starter

podman-run-ssl:
	podman run --name zapped-ssl --privileged --userns=keep-id \
		-p 80:3000 -p 443:3443 \
		-e HOST=0.0.0.0 \
		-e PORT=3443 \
		-e USE_SSL=true \
		-e DOMAIN=${DOMAIN} \
		-e EMAIL=${EMAIL} \
		zapped-starter

# Run privacy build with SSL
docker-run-privacy-ssl:
	docker volume create i2pd-data || true
	docker run --name zapped-privacy-ssl -p 80:3000 -p 443:3443 \
		-p 9050:9050 \
		$(if $(USE_I2P),-p 7656:7656 -v i2pd-data:/var/lib/i2pd) \
		-e HOST=0.0.0.0 \
		-e PORT=3443 \
		-e USE_SSL=true \
		-e USE_I2P=$(USE_I2P) \
		-e DOMAIN=${DOMAIN} \
		-e EMAIL=${EMAIL} \
		zapped-privacy

podman-run-privacy-ssl:
	podman volume create i2pd-data || true
	podman run --name zapped-privacy-ssl --privileged --userns=keep-id \
		-p 80:3000 -p 443:3443 \
		-p 9050:9050 \
		$(if $(USE_I2P),-p 7656:7656 -v i2pd-data:/var/lib/i2pd:Z) \
		-e HOST=0.0.0.0 \
		-e PORT=3443 \
		-e USE_SSL=true \
		-e USE_I2P=$(USE_I2P) \
		-e DOMAIN=${DOMAIN} \
		-e EMAIL=${EMAIL} \
		zapped-privacy

# Add container management targets
stop:
	$(CONTAINER_ENGINE) stop zapped-standard zapped-privacy zapped-ssl zapped-privacy-ssl 2>/dev/null || true

rm:
	$(CONTAINER_ENGINE) rm zapped-standard zapped-privacy zapped-ssl zapped-privacy-ssl 2>/dev/null || true
	# Uncomment the next line if you want to remove the volume on container cleanup
	# $(CONTAINER_ENGINE) volume rm i2pd-data 2>/dev/null || true

restart: stop rm
	make $(CONTAINER_ENGINE)-run

restart-privacy: stop rm
	make $(CONTAINER_ENGINE)-run-privacy

# Help target
help:
	@echo "Available targets:"
	@echo "Build targets:"
	@echo "  make build              - Build the project"
	@echo "  make run               - Run in development mode"
	@echo "  make safe              - Build with safety checks"
	@echo "  make clean             - Clean build artifacts"
	@echo
	@echo "Container targets ($(CONTAINER_ENGINE)):"
	@echo "  make docker/podman            - Build standard container image"
	@echo "  make docker-privacy/podman-privacy    - Build privacy container image"
	@echo "  make docker-run/podman-run        - Run standard container"
	@echo "  make docker-run-privacy/podman-run-privacy - Run privacy container"
	@echo "  make docker-run-ssl/podman-run-ssl    - Run with SSL"
	@echo "  make docker-run-privacy-ssl/podman-run-privacy-ssl - Run privacy with SSL"
	@echo
	@echo "Environment variables:"
	@echo "  ENGINE                 - Container engine to use (docker/podman)"
	@echo "  DOMAIN                 - Domain for SSL certificate"
	@echo "  EMAIL                  - Email for SSL certificate"
	@echo
	@echo "Example usage:"
	@echo "  make podman"
	@echo "  make podman-run-ssl DOMAIN=example.com EMAIL=admin@example.com" 