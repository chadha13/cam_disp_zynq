# Vivado : vivado -mode batch -source tcl/build.tcl -tclargs <part>      (NON TESTE : pas de Vivado dans l'environnement de redaction)
# Prerequis : placer kcpsm6.vhd (AMD/Xilinx) et cam_disp.vhd (sortie de l'assembleur) dans rtl_extra/
set part [expr {$argc > 0 ? [lindex $argv 0] : "xc7z020clg400-1"}]   ;# A REMPLACER par la puce de votre carte
set root [file normalize [file dirname [info script]]/..]
create_project -force cam_disp_zynq $root/vivado -part $part
set_property target_language VHDL [current_project]
add_files [glob $root/rtl/*.vhd]
if {[llength [glob -nocomplain $root/rtl_extra/*.vhd]]} { add_files [glob $root/rtl_extra/*.vhd] } else {
  puts "ATTENTION : rtl_extra/kcpsm6.vhd et rtl_extra/cam_disp.vhd manquants (voir README)" }
set_property file_type {VHDL 2008} [get_files $root/rtl/*.vhd]
set_property top cam_disp_top [current_fileset]

# Sous-systeme MIPI DSI TX (les noms CONFIG.* sont a verifier : report_property [get_ips mipi_dsi_tx_ss_0])
create_ip -name mipi_dsi_tx_subsystem -vendor xilinx.com -library ip -module_name mipi_dsi_tx_ss_0
catch {set_property -dict [list CONFIG.DSI_LANES 2 CONFIG.DSI_PIXELS 1 CONFIG.DSI_DATATYPE RGB888 \
        CONFIG.DPHY_LINE_RATE 450] [get_ips mipi_dsi_tx_ss_0]} err
if {$err ne ""} { puts "Proprietes IP a ajuster manuellement : $err" }
generate_target all [get_ips mipi_dsi_tx_ss_0]
puts "Projet cree. Reste : block design (cam_disp_top en module reference + DSI + PS), XDC, puis synth/impl."
