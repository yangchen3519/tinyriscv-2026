# Add tinyriscv_4core sources to the currently open Vivado project.
# Usage from Vivado Tcl Console:
#   source D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/tools/vivado_add_sources.tcl
# Optional before source:
#   set TINYRISCV_TARGET fpga
#   set TINYRISCV_SIM_TB fourcore_rv32i_smoke_tb

set project_root [file normalize [file join [file dirname [info script]] ..]]
set sim_root [file join $project_root sim]

proc collect_filelist {filelist base_dir} {
    set result {}
    set fp [open $filelist r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] ||
            [string match "+incdir+*" $line] || [string match "-f *" $line]} {
            continue
        }
        lappend result [file normalize [file join $base_dir $line]]
    }
    close $fp
    return $result
}

# The chip/tapeout hierarchy is always a design source.  TINYRISCV_TARGET may
# be "chip" (default) or "fpga".  FPGA mode adds the single shared YC
# FPGA-side bridge, ROM, RAM and the synthesizable FPGA wrapper.
set chip_files [collect_filelist [file join $sim_root filelist.f] $sim_root]
add_files -norecurse -fileset sources_1 $chip_files
set_property include_dirs [list [file join $project_root rtl include]] [get_filesets sources_1]
if {![info exists TINYRISCV_TARGET]} {
    set TINYRISCV_TARGET chip
}
if {$TINYRISCV_TARGET eq "fpga"} {
    set fpga_files [collect_filelist [file join $project_root fpga filelist.f] [file join $project_root fpga]]
    add_files -norecurse -fileset sources_1 $fpga_files
    set_property top tinyriscv_4core_fpga_top [get_filesets sources_1]
} elseif {$TINYRISCV_TARGET eq "chip"} {
    set_property top tinyriscv_4core_top [get_filesets sources_1]
} else {
    error "TINYRISCV_TARGET must be chip or fpga"
}

# If TINYRISCV_SIM_TB is defined, add the selected TB.  Every end-to-end TB
# instantiates tinyriscv_4core_fpga_top, so the shared FPGA files are also
# added to sim_1 even when the design target is chip.
if {[info exists TINYRISCV_SIM_TB] && $TINYRISCV_SIM_TB ne ""} {
    set fpga_files [collect_filelist [file join $project_root fpga filelist.f] [file join $project_root fpga]]
    add_files -norecurse -fileset sim_1 $fpga_files
    set tb_file [file join $project_root tb ${TINYRISCV_SIM_TB}.v]
    if {![file exists $tb_file]} {
        error "testbench not found: $tb_file"
    }
    add_files -norecurse -fileset sim_1 $tb_file
    set_property include_dirs [list [file join $project_root rtl include]] [get_filesets sim_1]
    set_property top $TINYRISCV_SIM_TB [get_filesets sim_1]
    update_compile_order -fileset sim_1
    puts "Added chip RTL, shared YC FPGA storage wrapper and TB: $TINYRISCV_SIM_TB"
} else {
    puts "Added $TINYRISCV_TARGET RTL. Set TINYRISCV_SIM_TB before sourcing to add a testbench."
}

update_compile_order -fileset sources_1
