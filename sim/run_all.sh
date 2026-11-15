#!/bin/bash
# Regression GHDL (VHDL-2008) : ./run_all.sh   (stubs kcpsm6 / ROM utilises uniquement ici)
set -e; cd "$(dirname "$0")"; rm -rf work; mkdir work
R=../rtl
ghdl -a --std=08 -frelaxed --workdir=work $R/sync_bit.vhd $R/cam_disp_fsm.vhd $R/sccb_master.vhd $R/axil_ctrl.vhd \
  $R/async_fifo.vhd $R/dvp_capture.vhd $R/vid_out.vhd kcpsm6_stub.vhd cam_disp_rom_stub.vhd $R/pb_ctrl.vhd \
  $R/cam_disp_core.vhd $R/cam_disp_top.vhd tb_cam_disp_fsm.vhd tb_datapath.vhd tb_sccb.vhd 2>/dev/null
ghdl -e --std=08 -frelaxed --workdir=work cam_disp_top && echo "ELAB cam_disp_top : OK"
for t in tb_cam_disp_fsm tb_datapath; do ghdl -e --std=08 -frelaxed --workdir=work $t; ghdl -r --std=08 -frelaxed --workdir=work $t 2>&1 | grep -E "PASS|ECHEC|error" ; done
ghdl -e --std=08 -frelaxed --workdir=work tb_sccb
ghdl -r --std=08 -frelaxed --workdir=work tb_sccb 2>&1 | grep -E "PASS|ECHEC|error"
ghdl -r --std=08 -frelaxed --workdir=work tb_sccb -gDO_READ=true 2>&1 | grep -E "PASS|ECHEC|error"
