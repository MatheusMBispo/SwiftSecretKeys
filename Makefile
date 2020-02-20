prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/swiftsecrets" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/swiftsecrets"

clean:
	rm -rf .build
	rm -rf *.xcodeproj

project:
	swift package generate-xcodeproj
	open *.xcodeproj

.PHONY: build install uninstall clean