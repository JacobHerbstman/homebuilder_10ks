SHELL := bash
.DELETE_ON_ERROR:

../input ../output ../temp slurmlogs:
	mkdir -p $@

run.sbatch: ../../setup_environment/code/run.sbatch | slurmlogs
	@test "$$(readlink "$@")" = "$<" || ln -sf $< $@

.PHONY: link-inputs FORCE
link-inputs:
.PRECIOUS: ../../% ../../../%

ifeq ($(wildcard ../../../generic.make),../../../generic.make)

UPSTREAM_TASKS := $(notdir $(patsubst %/code,%,$(wildcard ../../../*/code)))
UPSTREAM_AUDITS := $(notdir $(patsubst %/code,%,$(wildcard ../../*/code)))

define UPSTREAM_OUTPUT_RULE
../../../$(1)/output/%: FORCE
	@$$(MAKE) --no-print-directory -s -C ../../../$(1)/code ../output/$$*
endef

$(foreach task,$(UPSTREAM_TASKS),$(eval $(call UPSTREAM_OUTPUT_RULE,$(task))))

define UPSTREAM_AUDIT_OUTPUT_RULE
../../$(1)/output/%: FORCE
	@$$(MAKE) --no-print-directory -s -C ../../$(1)/code ../output/$$*
endef

$(foreach task,$(UPSTREAM_AUDITS),$(eval $(call UPSTREAM_AUDIT_OUTPUT_RULE,$(task))))

else

UPSTREAM_TASKS := $(notdir $(patsubst %/code,%,$(wildcard ../../*/code)))
UPSTREAM_AUDITS := $(notdir $(patsubst %/code,%,$(wildcard ../../audits/*/code)))

define UPSTREAM_OUTPUT_RULE
../../$(1)/output/%: FORCE
	@$$(MAKE) --no-print-directory -s -C ../../$(1)/code ../output/$$*
endef

define UPSTREAM_AUDIT_OUTPUT_RULE
../../audits/$(1)/output/%: FORCE
	@$$(MAKE) --no-print-directory -s -C ../../audits/$(1)/code ../output/$$*
endef

$(foreach task,$(UPSTREAM_TASKS),$(eval $(call UPSTREAM_OUTPUT_RULE,$(task))))
$(foreach task,$(UPSTREAM_AUDITS),$(eval $(call UPSTREAM_AUDIT_OUTPUT_RULE,$(task))))

endif

FORCE:
