Can you write a really simple encoder in C.

How the program should work:

You display a menu with the 9 possible configuration options
The user selects a configuration
You load the G file from the .mat file located in directory ccsds_ldpc\c\build_g
You generate a random message with a size that matches the configuration
You encode it using the G matrix: you compute m × G, and optionally remove the puncturing
Then you load H from its .mat file from directory ccsds_ldpc\c\build_h
You verify that the encoding is correct
You display that the test has passed
You close the program
Do an extra option, is to pass the menu option as an arguement of launchine the exe so then the menu is bypassed