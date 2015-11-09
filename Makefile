# -*- makefile-gmake -*-
UMAKEFILES += Makefile
ifneq "$(INCLUDE)" "no"
ifeq ($(shell test -f build/Makefile-configuration && echo yes),yes)
UMAKEFILES += build/Makefile-configuration
include build/Makefile-configuration
endif
endif
############################################
# The packages, listed in reverse order by dependency:
PACKAGES += SubstitutionSystems
PACKAGES += Tactics
PACKAGES += Dedekind
PACKAGES += Ktheory
PACKAGES += CategoryTheory
PACKAGES += Foundations
############################################
# other user options; see also build/Makefile-configuration-template
BUILD_COQ ?= yes
BUILD_COQIDE ?= no
COQBIN ?=
############################################
.PHONY: all everything install lc lcp wc describe clean distclean build-coq doc build-coqide
COQIDE_OPTION ?= no
ifeq "$(BUILD_COQ)" "yes"
COQBIN=sub/coq/bin/
all: build-coq
build-coq: sub/coq/bin/coqc
ifeq "$(BUILD_COQIDE)" "yes"
all: build-coqide
build-coqide: sub/coq/bin/coqide
COQIDE_OPTION := opt
LABLGTK := -lablgtkdir "$(shell pwd)"/sub/lablgtk/src
endif
endif

# override the definition in build/CoqMakefile.make, to eliminate the -utf8 option
COQDOC := coqdoc
COQDOCFLAGS := -interpolate --charset utf-8
COQDOC_OPTIONS := -toc $(COQDOCFLAGS) $(COQDOCLIBS) -utf8

PACKAGE_FILES := $(patsubst %, UniMath/%/.package/files, $(PACKAGES))

ifneq "$(INCLUDE)" "no"
include build/CoqMakefile.make
endif
everything: TAGS all html install
OTHERFLAGS += $(MOREFLAGS)
OTHERFLAGS += -indices-matter -type-in-type
ifeq ($(VERBOSE),yes)
OTHERFLAGS += -verbose
endif
ENHANCEDDOCTARGET = enhanced-html
ENHANCEDDOCSOURCE = util/enhanced-doc
LATEXTARGET = latex
COQDOCLATEXOPTIONS := -utf8 -p "\usepackage{textgreek}\usepackage{stmaryrd}\DeclareUnicodeCharacter{10627}{{\(\llparenthesis\)}}\DeclareUnicodeCharacter{10628}{{\(\rrparenthesis\)}}\DeclareUnicodeCharacter{10815}{{\(\amalg\)}}\DeclareUnicodeCharacter{9679}{{\(\bullet\)}}"
COQDEFS := --language=none -r '/^[[:space:]]*\(Local[[:space:]]+\)?\(Axiom\|Theorem\|Class\|Instance\|Let\|Ltac\|Definition\|Lemma\|Record\|Remark\|Structure\|Fixpoint\|Fact\|Corollary\|Let\|Inductive\|Coinductive\|Notation\|Proposition\|Module[[:space:]]+Import\|Module\)[[:space:]]+\([[:alnum:]'\''_]+\)/\3/'
$(foreach P,$(PACKAGES),$(eval TAGS-$P: $(filter UniMath/$P/%,$(VFILES)); etags -o $$@ $$^))
$(VFILES:.v=.vo) : $(COQBIN)coqc
TAGS : $(PACKAGE_FILES) $(VFILES); etags $(COQDEFS) $(VFILES)
FILES_FILTER := grep -vE '^[[:space:]]*(\#.*)?$$'
$(foreach P,$(PACKAGES),$(eval $P: $(shell <UniMath/$P/.package/files $(FILES_FILTER) |sed "s=^\(.*\)=UniMath/$P/\1o=" )))
install:all
coqwc:; coqwc $(VFILES)
lc:; wc -l $(VFILES)
lcp:; for i in $(PACKAGES) ; do echo ; echo ==== $$i ==== ; for f in $(VFILES) ; do echo "$$f" ; done | grep "UniMath/$$i" | xargs wc -l ; done
wc:; wc -w $(VFILES)
describe:; git describe --dirty --long --always --abbrev=40 --all
.coq_makefile_input: $(PACKAGE_FILES) $(UMAKEFILES)
	@ echo making $@ ; ( \
	echo '# -*- makefile-gmake -*-' ;\
	echo ;\
	echo '# DO NOT EDIT THIS FILE!' ;\
	echo '# It is made by automatically (by code in Makefile)' ;\
	echo ;\
	echo '-Q UniMath UniMath' ;\
	echo ;\
	for i in $(PACKAGES) ;\
	do <UniMath/$$i/.package/files $(FILES_FILTER) |sed "s=^=UniMath/$$i/="  ;\
	done ;\
	echo ;\
	echo '# Local ''Variables:' ;\
	echo '# compile-command: "sub/coq/bin/coq_makefile -f .coq_makefile_input -o CoqMakefile.make.tmp && mv CoqMakefile.make.tmp build/CoqMakefile.make"' ;\
	echo '# End:' ;\
	) >$@
# the '' above prevents emacs from mistaking the lines above as providing local variables when visiting this file
build/CoqMakefile.make: .coq_makefile_input $(COQBIN)coq_makefile
	$(COQBIN)coq_makefile -f .coq_makefile_input -o .coq_makefile_output
	mv .coq_makefile_output $@

# "clean::" occurs also in build/CoqMakefile.make, hence both colons
clean::
	rm -f .coq_makefile_output build/CoqMakefile.make
	find UniMath \( -name .\*.aux -o -name \*.glob -o -name \*.v.d -o -name \*.vo \) -delete
	find UniMath -type d -empty -delete
clean::          ; rm -rf $(ENHANCEDDOCTARGET)
clean::          ; rm -rf $(LATEXTARGET)

distclean:: clean
distclean::          ; - $(MAKE) -C sub/coq distclean
distclean::          ; rm -f build/Makefile-configuration

# building coq:
export PATH:=$(shell pwd)/sub/coq/bin:$(PATH)
sub/lablgtk/README:
	git submodule update --init sub/lablgtk
sub/coq/configure sub/coq/configure.ml:
	git submodule update --init sub/coq
ifeq "$(BUILD_COQ) $(BUILD_COQIDE)" "yes yes"
sub/coq/config/coq_config.ml: sub/lablgtk/src/gSourceView2.cmi
endif
sub/coq/config/coq_config.ml: sub/coq/configure sub/coq/configure.ml
	: making $@ because of $?
	cd sub/coq && ./configure -coqide "$(COQIDE_OPTION)" $(LABLGTK) -with-doc no -annotate -debug -local
# instead of "coqlight" below, we could use simply "theories/Init/Prelude.vo"
sub/coq/bin/coq_makefile sub/coq/bin/coqc: sub/coq/config/coq_config.ml
	$(MAKE) -C sub/coq KEEP_ML4_PREPROCESSED=true VERBOSE=true READABLE_ML4=yes coqbinaries tools states
sub/coq/bin/coqide: sub/lablgtk/README sub/coq/config/coq_config.ml
	$(MAKE) -C sub/coq KEEP_ML4_PREPROCESSED=true VERBOSE=true READABLE_ML4=yes coqide-binaries bin/coqide
configure-coq: sub/coq/config/coq_config.ml
# we use sub/lablgtk/src/gSourceView2.cmi as a proxy for all of lablgtk
# note: under Mac OS X, "homebrew" installs lablgtk without that file, but it's needed for building coqide.  That's why we build lablgtk ourselves.
# note: lablgtk needs camlp4, not camlp5.  Strange, but it does.  So we must install that, too.
build-lablgtk sub/lablgtk/src/gSourceView2.cmi: sub/lablgtk/README
	cd sub/lablgtk && ./configure
	$(MAKE) -C sub/lablgtk all byte opt world
git-describe:
	git describe --dirty --long --always --abbrev=40
	git submodule foreach git describe --dirty --long --always --abbrev=40 --tags
doc: $(GLOBFILES) $(VFILES) 
	mkdir -p $(ENHANCEDDOCTARGET)
	cp $(ENHANCEDDOCSOURCE)/proofs-toggle.js $(ENHANCEDDOCTARGET)/proofs-toggle.js
	$(COQDOC) -toc $(COQDOCFLAGS) -html $(COQDOCLIBS) -d $(ENHANCEDDOCTARGET) \
	--with-header $(ENHANCEDDOCSOURCE)/header.html $(VFILES)
	sed -i'.bk' -f $(ENHANCEDDOCSOURCE)/proofs-toggle.sed $(ENHANCEDDOCTARGET)/*html

world: all html doc pdffiles

texfiles : $(VFILES:%.v=$(LATEXTARGET)/%.tex)

$(foreach F, $(VFILES:.v=),								\
        $(eval $(LATEXTARGET)/$F.tex : $F.glob $F.v ;					\
		mkdir -p $(shell dirname $(LATEXTARGET)/$F) &&				\
		$(COQDOC) $(COQDOCLATEXOPTIONS) -latex $F.v -o $$@	\
                ))

pdffiles : $(VFILES:%.v=$(LATEXTARGET)/%.pdf)

$(foreach F, $(VFILES:.v=),								\
	$(eval $(LATEXTARGET)/$F.pdf : $(LATEXTARGET)/$F.tex ;				\
		cd $(shell dirname $(LATEXTARGET)/$F) &&				\
		pdflatex $(shell basename $(LATEXTARGET)/$F.tex)			\
		)) 

#################################
# targets best used with INCLUDE=no
git-clean:
	git clean -Xdfq
	git submodule foreach git clean -xdfq
git-deinit:
	git submodule foreach git clean -xdfq
	git submodule deinit -f sub/*
#################################
