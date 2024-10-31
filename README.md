# Row Stationary Convolution Accelerator

PE Cluster modelled after Eyeriss

Completely flexible in terms of the activation size and kernel size
Assumes square kernel and activations

Generate the input files using the ipynb, and then change the top two
parameters of the testbench before running.

### How to run

1. Run test.ipynb in one of the folders to create the input text files.
2. `cd sim`
3. and then you can use your simulator of choice.

### Todo

* PE cluster control based on layer information metadata (currently the row-stationary control is inside a testbench)
* Saturation logic + lower output precision
* Actual buffer logic, single cycle input delay