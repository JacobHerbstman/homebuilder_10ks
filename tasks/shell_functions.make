FUNCTIONS = $(shell cat ../../shell_functions.sh)
STATA = @$(FUNCTIONS); stata_with_flag
R = @$(FUNCTIONS); R_pc_and_slurm

# If make is invoked with -n, print the underlying command instead of the shell function.
ifneq (,$(findstring n,$(filter-out --%,$(MAKEFLAGS))))
STATA := STATA
R := R
endif
