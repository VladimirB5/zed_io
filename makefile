All: axi_design
	vvp axi_design


axi_design: axi_gpio_tb.v axi_gpio.v synchro.v
	iverilog -o axi_design  axi_gpio_tb.v axi_gpio.v synchro.v