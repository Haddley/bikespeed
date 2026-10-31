// The code is in brake_test.cpp.
//
// It is kept out of this .ino file on purpose. For an .ino file, the Arduino build
// generates function prototypes with a tool that, on this Mac, drops the return type
// and inserts stray "setup();" and "loop();" lines into the middle of the interrupt
// handler. Plain .cpp files are not processed that way.
