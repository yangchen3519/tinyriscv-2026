VCS      ?= vcs
VERDI    ?= verdi
TOP      ?= shared_arbiter_tb
TB       ?= ../tb/$(TOP).v
SIMV     ?= simv_$(TOP)
LOGDIR   ?= ../output/vcs
FPGA_RTL = ../fpga/rtl/yc_bridge_FPGA.v ../fpga/rtl/yc_rom.v \
	../fpga/rtl/yc_ram.v ../fpga/rtl/tinyriscv_4core_fpga_top.v
EXTRA_RTL ?=

VCS_FLAGS = -full64 +v2k -timescale=1ns/1ps -debug_access+all -kdb \
	+define+FSDB -f filelist.f

ifdef VERDI_HOME
NOVAS_PLI = -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
	$(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
endif

.PHONY: compile run verdi arbiter uart_debug rv32i clean

compile:
	mkdir -p $(LOGDIR)
	$(VCS) $(VCS_FLAGS) $(NOVAS_PLI) $(EXTRA_RTL) $(TB) -top $(TOP) \
		-o $(SIMV) -l $(LOGDIR)/$(TOP)_compile.log

run: compile
	./$(SIMV) $(RUN_ARGS) -l $(LOGDIR)/$(TOP).log
	grep -q TEST_PASS $(LOGDIR)/$(TOP).log
	! grep -q TEST_FAIL $(LOGDIR)/$(TOP).log

arbiter:
	$(MAKE) run TOP=shared_arbiter_tb

uart_debug:
	$(MAKE) run TOP=shared_uart_debug_tb EXTRA_RTL="$(FPGA_RTL)"

rv32i:
	$(MAKE) run TOP=fourcore_rv32i_smoke_tb EXTRA_RTL="$(FPGA_RTL)" \
		RUN_ARGS="+INST_FILE=../firmware/test_command/Baisc_Inst_Example/inst_add.data"

verdi:
	$(VERDI) -ssf $(LOGDIR)/$(TOP).fsdb -f filelist.f $(EXTRA_RTL) $(TB) -top $(TOP) &

clean:
	rm -rf csrc simv_* simv_*.daidir ucli.key DVEfiles verdiLog novas.conf novas.rc
