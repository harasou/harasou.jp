.PHONY: deploy build server public clean new

HUGO := hugo
PREFIX := $(shell date +post/%Y-%m-%d)
IMGDIR := $(shell date +static/%Y/%m/%d)

deploy: build
	gcloud app deploy

build: clean
	$(HUGO)

server:
	$(HUGO) server -vD

public: clean
	$(HUGO) --baseURL http://127.0.0.1:8080/
	docker run -it --rm -p 8080:8080 -v $(CURDIR)/public:/public harasou/http-fileserver

clean:
	@-rm -rf public/
	@-find static -type d -empty | xargs rmdir

new:
	@: dummy

.DEFAULT:
	@case $(firstword $(MAKECMDGOALS)) in \
	new) \
		mkdir -p $(IMGDIR)/$@; \
		$(HUGO) new $(PREFIX)-$@.md --editor vim; \
		;; \
	esac
