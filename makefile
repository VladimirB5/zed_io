All: axi_design
	vvp axi_design


axi_design: axi_gpio_tb.v axi_gpio_top.v synchro.v debouncer.v axi_lite.v int_ctrl.v
	iverilog -o axi_design  axi_gpio_tb.v axi_gpio_top.v synchro.v debouncer.v axi_lite.v int_ctrl.v
	
clean: 
	rm -f axi_design *.vcd
