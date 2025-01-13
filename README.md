# Row Stationary Convolution Accelerator

PE Cluster modelled after Eyeriss

* Completely flexible in terms of the activation size and kernel size.

* Assumes square kernel and activations.

Generate the input files using the ipynb, and then change the top two parameters of the testbench before running.

There are two versions of the cluster: one with a behavioral multicast network description (PE_cluster.sv) and one where the multicast network is hardcoded to be similar to the Eyeriss paper (PE_cluster_smc.sv).

### How to run

Run `pytest`. 
This will run all the tests in the tests directory, and output the testbench outputs to tests/log.
Changing the seed will change the values for all test arrays (but not the sizes thereof).

To test against sizes, manually modify test_all.py and change the appropriate values in the calls to the stimulus generators.

### Todo

* PE cluster control based on layer information metadata (currently the row-stationary control is inside a testbench)
* Saturation logic
* Accelerator
* AXI Interface