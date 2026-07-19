# vim: noexpandtab

export GO111MODULE = on
export CGO_ENABLED = 1
export CGO_CFLAGS = -g -O2 -Wno-return-local-addr

PACKAGE_ROOT = gitlab.com/lightmeter/controlcenter
PACKAGE_VERSION = ${PACKAGE_ROOT}/version
APP_VERSION = `cat VERSION.txt`

ifneq ($(wildcard .git),)
	GIT_COMMIT = `git rev-parse --short HEAD`
	GIT_BRANCH = `git describe --tags --exact-match 2>/dev/null || git symbolic-ref -q --short HEAD`
else
	GIT_COMMIT = ""
	GIT_BRANCH = ""
endif

BUILD_INFO_FLAGS = -X ${PACKAGE_VERSION}.Commit=${GIT_COMMIT} -X ${PACKAGE_VERSION}.TagOrBranch=${GIT_BRANCH} -X ${PACKAGE_VERSION}.Version=${APP_VERSION}

all:
	$(error Use make (dev|release|static_release) instead)

race:
	./tools/go_test.sh -race

BUILD_DEPENDENCIES = go gcc ragel npm bash
$(foreach exec,$(BUILD_DEPENDENCIES),\
    $(if $(shell command -v $(exec) 2> /dev/null),$(info Found executable `$(exec)`),$(error "Build dependency program $(exec) could not be found in PATH. Check README.md for more info")))

dev_headless_pre_build: mocks translations swag static_www postfix_parser domain_mapping_list po2go www

pre_build: export SKIP_VUE_SOURCE_MAPS := false
dev_pre_build: npminstall mocks translations frontend_root swag static_www postfix_parser domain_mapping_list po2go

pre_build: export SKIP_VUE_SOURCE_MAPS := true
pre_build: npminstall translations frontend_root static_www postfix_parser domain_mapping_list po2go email_notification_template

pre_release: pre_build recommendation_release

dev_bin: dev_pre_build recommendation_dev
	go build -tags="dev include no_postgres no_mysql no_clickhouse no_mssql" -o "lightmeter" -ldflags "${BUILD_INFO_FLAGS}"

dev_headless_bin: dev_headless_pre_build recommendation_dev
	go build -tags="dev include no_postgres no_mysql no_clickhouse no_mssql" -o "lightmeter" -ldflags "${BUILD_INFO_FLAGS}"

release_bin: pre_release
	go build -tags="release include no_postgres no_mysql no_clickhouse no_mssql" -o "lightmeter" -ldflags "${BUILD_INFO_FLAGS}"

static_release_bin: pre_release
	go build -tags="release include no_postgres no_mysql no_clickhouse no_mssql" -o "lightmeter" -ldflags \
		"${BUILD_INFO_FLAGS} -linkmode external -extldflags '-static' -s -w" -a -v

static_www:
	go generate -tags="include" gitlab.com/lightmeter/controlcenter/staticdata

email_notification_template:
	go generate gitlab.com/lightmeter/controlcenter/notification/email

domain_mapping_list: domainmapping/generated_list.go

domainmapping/generated_list.go: domainmapping/mapping.json
	go generate gitlab.com/lightmeter/controlcenter/domainmapping

recommendation_dev:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/recommendation

recommendation_release:
	go generate -tags="release" gitlab.com/lightmeter/controlcenter/recommendation

mocks: postfix_parser dashboard_mock insights_mock detective_mock intel_mock timeutil_mock

dashboard_mock:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/dashboard

insights_mock:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/insights/core

intel_mock:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/intel/receptor

timeutil_mock:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/util/timeutil

detective_mock:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/detective

po2go:
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/po

go2po:
	go run tools/go2po/main.go -i . -o po/backend.pot
	go run tools/go2po/main.go -i . -o po/en/LC_MESSAGES/backend.po

swag: www
	go generate -tags="dev" gitlab.com/lightmeter/controlcenter/api
	cp api/docs/swagger.json www/api.json

clean: clean_binaries clean_swag clean_staticdata clean_mocks clean_postfix_parser
	rm -f dependencies.svg

clean_binaries:
	rm -f lightmeter lightmeter.exe

clean_staticdata:
	rm -f staticdata/http_vfsdata.go

clean_swag:
	rm -f docs/docs.go docs/swagger.json docs/swagger.yaml www/api.json

clean_mocks:
	rm -f dashboard/mock/dashboard_mock.go

dependencies.svg: go.sum go.mod
	go mod graph | tools/gen_deps_graph.py | dot -Tsvg > dependencies.svg

postfix_parser:
	go generate gitlab.com/lightmeter/controlcenter/pkg/postfix/logparser/rawparser

clean_postfix_parser:
	@rm -vf pkg/postfix/logparser/rawparser/*.gen.go

TRANSLATION_OUTPUT = ./frontend/controlcenter/src/translation/translations.json
FRONTEND_NODE_MODULES = ./frontend/controlcenter/node_modules/.bin/vue-cli-service

$(FRONTEND_NODE_MODULES): frontend/controlcenter/package.json frontend/controlcenter/package-lock.json
	cd frontend/controlcenter && npm ci --no-audit --no-fund

npminstall: $(FRONTEND_NODE_MODULES)

serve_frontend_dev: npminstall
	cd frontend/controlcenter && npm run serve

www:
	mkdir -p ./www

frontend_root: $(FRONTEND_NODE_MODULES) www $(TRANSLATION_OUTPUT)
	sh ./frontend/controlcenter/root_build.sh

release: release_bin

dev: dev_bin

devheadless: dev_headless_bin

static_release: static_release_bin

#template from https://github.com/Polyconseil/vue-gettext/blob/master/Makefile

NODE_BINDIR = ./frontend/controlcenter/node_modules/.bin
export PATH := $(NODE_BINDIR):$(PATH)
LOGNAME ?= $(shell logname)

# adding the name of the user's login name to the template file, so that
# on a multi-user system several users can run this without interference
UI_TEMPLATE_POT ?= ./po/webui.pot

# Where to find input files (it can be multiple paths).
INPUT_FILES = ./frontend/controlcenter/src

# Where to write the files generated by this makefile.
OUTPUT_DIR = ./po

# Name of the generated .po files for each available locale.
LOCALE_FILES ?= $(shell find $(OUTPUT_DIR) -name webui.po)

GETTEXT_SOURCES ?= $(shell find $(INPUT_FILES) -name '*.jade' -o -name '*.html' -o -name '*.js' -o -name '*.vue' 2> /dev/null)

cleantemplatepot:
	rm -f $(UI_TEMPLATE_POT)

messages: go2po $(UI_TEMPLATE_POT) $(OUTPUT_DIR)/en/LC_MESSAGES/webui.po

$(OUTPUT_DIR)/en/LC_MESSAGES/webui.po: $(GETTEXT_SOURCES)
	mkdir -p $$(dirname $@);
	msginit --no-translator --locale=en --input=$(UI_TEMPLATE_POT) --output-file=$@
	msgattrib --no-wrap --no-obsolete -o $@ $@

$(UI_TEMPLATE_POT): frontend/controlcenter/node_modules/.bin/gettext-extract $(GETTEXT_SOURCES)
	mkdir -p $(dir $@)
	gettext-extract --quiet --attribute v-translate --output $@ $(GETTEXT_SOURCES)

frontend/controlcenter/node_modules/.bin/gettext-compile:
	cd frontend/controlcenter && npm ci --no-audit --no-fund

frontend/controlcenter/node_modules/.bin/gettext-extract:
	cd frontend/controlcenter && npm ci --no-audit --no-fund

# Convert po files to vue.js format
vuejs-translations: $(TRANSLATION_OUTPUT) frontend/controlcenter/node_modules/.bin/gettext-compile
	gettext-compile --output $(TRANSLATION_OUTPUT) $(LOCALE_FILES) || true

translations: vuejs-translations

update_cli_docs:
	./tools/update_cli_docs.sh

$(TRANSLATION_OUTPUT):
	mkdir -p `dirname $@`
	echo "{}" > $@
