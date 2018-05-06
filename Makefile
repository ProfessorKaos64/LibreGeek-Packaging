# https://github.com/mdeguzis/libregeek-repo
GPG_KEYID := 57655DD5
REPO := repo/
BUILD_DIR := ./build
OPTIONS += --ccache 
OPTIONS += --force-clean 
OPTIONS += --rebuild-on-sdk-change 
OPTIONS += --require-changes 
OPTIONS += --gpg-sign=$(GPG_KEYID) 
OPTIONS += --repo=$(REPO) $(BUILD_DIR)
BUILD_CMD = sudo flatpak-builder $(OPTIONS)

# Intended for testing a module build
MODULE ?= 

check:
	$(info $$BUILD_DIR is [${BUILD_DIR}])
	$(info $$GPG_KEYID is [${GPG_KEYID}])
	$(info $$OPTIONS are [${OPTIONS}])
	$(info $$MODULE is [${MODULE}])

citra:
	cd org.citra_emu.Citra.json && $(BUILD_CMD)

module:
	@if [ -z $(MODULE) ]; then \
		echo "MODULE var is not set!"; \
		exit 1; \
	fi
	cd $(CURDIR)/$(shell dirname $(MODULE)) && $(BUILD_CMD) $(shell basename $(MODULE))

plex: 
	cd plex && $(BUILD_CMD) tv.plex.PlexMediaPlayer.yaml

sync: $(REPO)
	cd /mnt/server_media_y/packaging/flatpak && ./sync-flatpak-repo.sh

test:
	cd tests && $(BUILD_CMD) test.yaml

.PHONY: all plex
