# Controlling FPGA's led with UART 

In this example we have demonstrated how to turn on and off the on board led on shrike using a uart command from the rp2040 or any other uart controller.

For this a uart reciever is implemented on the fpga and when it receives the data 0xAB it turn's on the led and when it receives 0xFF it turn's it off.

The example works on 115200 baud rate however you can change it form the parameter in the top module.

The python script for the rp2040 is also include here.

Try these with this as base.

#### More addons to try 

 * Blink led in diffrent frequency when diffrent words are received from the uart
 * Display diffrent patterns on the led pmod based on the uart input word
 * Print the recived word on a digit display.

