`timescale 1ns/1ps

module tb_PE_cluster;

// Parameters from DUT
parameter numPeX = 3;
parameter numPeY = 3;
parameter interfaceSize = 64;
parameter dataSize = 8;
parameter wSpadNReg = 16;
parameter aSpadNReg = 16;
parameter rfNumRegister = 16;
parameter idSize = 8;

// Local parameters
parameter CLK_PERIOD = 20;
parameter MAX_CYCLES = 1000;

// Testbench signals
logic clk;
logic nrst;
logic signed [dataSize-1:0] w_data_i;
logic signed [dataSize-1:0] a_data_i;
logic [7:0] ctrl_acount;
logic [7:0] ctrl_wcount;
logic start_compute_i;
logic mc_controller_id_wren_i;
logic cluster_enable_i;
logic flag_done;
logic [idSize-1:0] act_id_scan_i;
logic [idSize-1:0] weight_id_scan_i;

// File handles
integer a_file, w_file, o_file, id_file;
integer scan_file;
logic signed [dataSize-1:0] expected_output;
integer error_count;

// Test memories
localparam wBufferDepth = 2**16;
localparam aBufferDepth = 2**16;
localparam oBufferDepth = 2**16;
logic signed [wBufferDepth-1:0][dataSize-1:0] weight_buffer;
logic signed [aBufferDepth-1:0][dataSize-1:0] act_buffer;
logic signed [oBufferDepth-1:0][numPeX-1:0][dataSize-1:0] out_buffer;

// DUT instantiation
PE_cluster #(
    .numPeX(numPeX),
    .numPeY(numPeY),
    .interfaceSize(interfaceSize),
    .dataSize(dataSize),
    .wSpadNReg(wSpadNReg),
    .aSpadNReg(aSpadNReg),
    .rfNumRegister(rfNumRegister),
    .idSize(idSize)
) dut (
    .clk(clk),
    .nrst(nrst),
    .w_data_i(w_data_i),
    .a_data_i(a_data_i),
    .ctrl_acount(ctrl_acount),
    .ctrl_wcount(ctrl_wcount),
    .start_compute_i(start_compute_i),
    .mc_controller_id_wren_i(mc_controller_id_wren_i),
    .cluster_enable_i(cluster_enable_i),
    .flag_done(flag_done),
    .act_id_scan_i(act_id_scan_i),
    .weight_id_scan_i(weight_id_scan_i)
);

// Clock generation
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// Test stimulus
initial begin
    // Files
    a_file = $fopen("a.txt", "r");
    w_file = $fopen("w.txt", "r");
    o_file = $fopen("o.txt", "r");
    id_file = $fopen("ids.txt", "r");

    // Init
    nrst = 0;
    w_data_i = 0;
    a_data_i = 0;
    ctrl_acount = 0;
    ctrl_wcount = 0;
    start_compute_i = 0;
    mc_controller_id_wren_i = 0;
    cluster_enable_i = 0;
    error_count = 0;
    id_scan_i = 0;

    // Cluster config
    ctrl_acount = 10;
    ctrl_wcount = 3;

    // Reset
    #(CLK_PERIOD*2);
    nrst = 1;
    #(CLK_PERIOD*2);
    cluster_enable_i = 1;
    
    // 1. Scan in multicast IDs
    $display("Scanning in multicast IDs...");
    while(!$feof(id_file)) begin
        scan_file = $fscanf(id_file, "%d", id_scan_i)
        #(CLK_PERIOD)
    end

    // 1.1. Flash it in
    mc_controller_id_wren_i = 1;

    // 2. Load in weights and activations


    // Start computation
    $display("Starting computation...");
    start_compute_i = 1;
    #(CLK_PERIOD);
    start_compute_i = 0;

    // Verify output
    $display("Verifying output...");
    while (!$feof(o_file)) begin
        scan_file = $fscanf(o_file, "%d\n", expected_output);
        // Compare with DUT output
        // Note: You'll need to add appropriate comparison logic here
        // based on how your PE cluster outputs results
        #(CLK_PERIOD);
    end

    // Close files
    $fclose(a_file);
    $fclose(w_file);
    $fclose(o_file);

    // Report results
    if (error_count == 0)
        $display("Test passed successfully!");
    else
        $display("Test failed with %d errors", error_count);

    $finish;
end

// Timeout watchdog
initial begin
    #(CLK_PERIOD*MAX_CYCLES);
    $display("Error: Simulation timeout after %d cycles", SIM_CYCLES);
    $finish;
end

// Optional: Waveform dump
initial begin
    $dumpfile("pe_cluster_tb.vcd");
    $dumpvars(0, PE_cluster_tb);
end

endmodule