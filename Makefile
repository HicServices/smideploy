SMIV	:= v5.2.0

JARS	:= ctpanonymiser-1.0.0/CTPAnonymiser-portable-1.0.0.jar smi-nerd-$(SMIV).jar
BINS	:=	smiinit
CXXFLAGS	:= -Wall -Wextra -O2 --std=c++11 -Iyaml-cpp/include

UNAME	:= $(shell uname)

.PHONY:	list clean distclean

all:	$(BINS)

publish:	docker
	echo $(DOCKERPW) | buildah login -u $(DOCKERU) --password-stdin docker.io
	buildah commit "$(ctr1)" "jas88/smi"
	buildah push jas88/smi docker://docker.io/jas88/smi:latest

docker: smiinit $(JARS) $(HOME)/rdmp-cli/rdmp ctp-whitelist.script smi-services-v3.0.2-linux-x64/default.yaml
	curl -L https://github.com/SMI/SmiServices/releases/download/$(SMIV)/smi-services-$(SMIV)-linux-x64.tgz | tar xzf -
	sed -i -e 's:MappingTable'"'"':smi.MappingTable'"'"':' smi-services-$(SMIV)-linux-x64/default.yaml
	sed -i -e 's/CTPAnonymiserOptions:/CTPAnonymiserOptions:\n    SRAnonTool: '\''\/smi\/dummy.sh'\''/' smi-services-$(SMIV)-linux-x64/default.yaml
	touch smi-services-$(SMIV)-linux-x64/dummy.sh
	$(eval ctr1:=$(shell buildah from docker://docker.io/debian:latest))
	buildah copy "$(ctr1)" smiinit /bin/
	buildah copy "$(ctr1)" $(HOME)/rdmp-cli /rdmp-cli
	buildah copy "$(ctr1)" $(JARS) ctp-whitelist.script smi-services-$(SMIV)-linux-x64/ /smi
	./eqnames.pl < smi-services-v3.0.2-linux-x64/default.yaml | buildah run "$(ctr1)" -- bash 2>&1 | tee dockerbuild.log
	buildah config --cmd "/bin/smiinit -c /smi -f /smi.yaml" "$(ctr1)"

$(HOME)/rdmp-cli/rdmp:	rdmp-cli-linux-x64.zip
	[ -e $@ ] || unzip -DD -d $(HOME)/rdmp-cli rdmp-cli-linux-x64.zip -x "Curation*" "zh-*"
	chmod +x $(HOME)/rdmp-cli/rdmp

rdmp-cli-linux-x64.zip:
	wget https://github.com/HicServices/RDMP/releases/download/v5.0.0/rdmp-cli-linux-x64.zip

ctpanonymiser-$(SMIV).zip:
	wget https://github.com/SMI/SmiServices/releases/download/$(SMIV)/ctpanonymiser-$(SMIV).zip

ctpanonymiser-1.0.0/CTPAnonymiser-portable-1.0.0.jar:	ctpanonymiser-$(SMIV).zip
	[ -e $@ ] || unzip -DD $<
	
smi-nerd-$(SMIV).jar:
	wget https://github.com/SMI/SmiServices/releases/download/$(SMIV)/smi-nerd-$(SMIV).jar

ctp-whitelist.script:
	wget https://raw.githubusercontent.com/SMI/SmiServices/$(SMIV)/data/ctp/ctp-whitelist.script

smiinit:	smiinit.cpp yaml-cpp/build/libyaml-cpp.a
ifeq ($(UNAME), Darwin)
	$(CXX) $(CXXFLAGS) -o $@ $^
else
	$(CXX) -static -s $(CXXFLAGS) -o $@ $^
endif

yaml-cpp/build/libyaml-cpp.a:
	mkdir -p yaml-cpp/build
	cd yaml-cpp/build && cmake .. && $(MAKE)

clean:
	$(RM) $(BINS) ctp-whitelist.script

distclean:	clean
	$(RM) -r yaml-cpp/build

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
