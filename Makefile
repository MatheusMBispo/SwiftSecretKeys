prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/sskeys" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/sskeys"

clean:
	rm -rf .build

.PHONY: build install uninstall clean