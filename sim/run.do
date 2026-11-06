# From the sim folder, in the ModelSim console:  do run.do
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog ../rtl/sdram_init.v ../tb/tb_sdram_init.v
vsim -onfinish stop -voptargs=+acc work.tb_sdram_init
add wave -radix hex /tb_sdram_init/dut/*
run -all
wave zoom full
