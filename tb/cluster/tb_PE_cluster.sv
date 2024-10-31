`timescale 1ns/1ps

module tb_PE_cluster;

// Parameters for DUT
parameter numPeX = 3;
parameter numPeY = 3;
parameter interfaceSize = 64;
parameter dataSize = 8;
parameter wSpadNReg = 16;
parameter aSpadNReg = 16;
parameter rfNumRegister = 16;
parameter idSize = 8;
parameter addrSize = 16;
localparam multResSize = dataSize*2;
localparam macResSize = multResSize + 4;
localparam numRegMulticastNetwork = numPeY*numPeX+numPeY;

// Local parameters
parameter CLK_PERIOD = 20;
parameter unsigned MAX_CYCLES = 1_000_000_000;
localparam wBufferDepth = 2**16;
localparam aBufferDepth = 2**16;
localparam oBufferDepth = 2**16;

// File handles
integer a_file, w_file, o_file, act_id_file, weight_id_file;
integer acts_tag_order_file, weights_tag_order_file;
integer scan_file;
logic signed [macResSize-1:0] expected_output;
integer error_count;
integer output_count;
integer output_element;
integer outputDimensionX;
integer outputDimensionY;

// Test memories
logic signed [wBufferDepth-1:0][dataSize-1:0] weight_buffer;
logic signed [aBufferDepth-1:0][dataSize-1:0] act_buffer;
logic signed [oBufferDepth-1:0][numPeX-1:0][dataSize-1:0] out_buffer;

// DUT Ports
logic clk;
logic nrst;
logic signed [dataSize-1:0] w_data_i;
logic signed [dataSize-1:0] a_data_i;
logic [7:0] ctrl_acount;
logic [7:0] ctrl_wcount;
logic act_id_wren_i;
logic weight_id_wren_i;
logic cluster_enable_i;
logic flag_done;
logic [idSize-1:0] act_id_scan_i;
logic [idSize-1:0] weight_id_scan_i;
logic [idSize-1:0] act_mcn_tag_target_x;
logic [idSize-1:0] weight_mcn_tag_target_x;
logic [idSize-1:0] act_mcn_tag_target_y;
logic [idSize-1:0] weight_mcn_tag_target_y;
logic [numPeX-1:0][macResSize-1:0] outs_write_data_o;
logic [addrSize-1:0] outs_write_addr_o;
logic outs_valid;
logic start_compute_i;

// DUT instantiation
PE_cluster #(
    .numPeX         (numPeX),
    .numPeY         (numPeY),
    .interfaceSize  (interfaceSize),
    .dataSize       (dataSize),
    .wSpadNReg      (wSpadNReg),
    .aSpadNReg      (aSpadNReg),
    .rfNumRegister  (rfNumRegister),
    .idSize         (idSize),
    .addrSize       (addrSize)
) u_PE_cluster (
    .clk                    (clk),
    .nrst                   (nrst),
    .w_data_i               (w_data_i),
    .a_data_i               (a_data_i),
    .outs_write_data_o      (outs_write_data_o),
    .outs_write_addr_o      (outs_write_addr_o),
    .outs_valid             (outs_valid),
    .start_compute_i        (start_compute_i),
    .act_mcn_tag_target_x   (act_mcn_tag_target_x),
    .weight_mcn_tag_target_x(weight_mcn_tag_target_x),
    .act_mcn_tag_target_y   (act_mcn_tag_target_y),
    .weight_mcn_tag_target_y(weight_mcn_tag_target_y),
    .ctrl_acount            (ctrl_acount),
    .ctrl_wcount            (ctrl_wcount),
    .cluster_enable_i       (cluster_enable_i),
    .flag_done              (flag_done),
    .act_id_scan_i          (act_id_scan_i),
    .weight_id_scan_i       (weight_id_scan_i),
    .act_id_wren_i          (act_id_wren_i),
    .weight_id_wren_i       (weight_id_wren_i)
);

// Fake output memory
localparam wMemSize = 1024;
localparam aMemSize = 1024;
// localparam oMemSize = 10;
logic signed [wMemSize-1:0][dataSize-1:0]                w_mem;
logic signed [aMemSize-1:0][dataSize-1:0]                a_mem;
logic signed [numPeX-1:0][numPeY-1:0][macResSize-1:0]    o_mem;

always @(posedge clk or negedge nrst) begin : registeredOmem
    if (!nrst) begin
        o_mem <= 0;
    end else begin
        if(outs_valid) begin
            for (int i = 0; i < numPeX; i = i + 1) begin
                o_mem[outs_write_addr_o][i] <= outs_write_data_o[i];
            end
        end
    end
end

// Clock generation
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// Test stimulus
initial begin

    string path = "../tb/cluster/";

    a_file = $fopen({path, "a.txt"}, "r");
    w_file = $fopen({path, "w.txt"}, "r");
    o_file = $fopen({path, "o.txt"}, "r");
    act_id_file = $fopen({path, "ids_acts.txt"}, "r");
    weight_id_file = $fopen({path, "ids_weights.txt"}, "r");
    acts_tag_order_file = $fopen({path, "tag_order_acts.txt"}, "r");
    weights_tag_order_file = $fopen({path, "tag_order_weights.txt"}, "r");

    // Init
    nrst = 0;
    w_data_i = 0;
    a_data_i = 0;
    ctrl_acount = 0;
    ctrl_wcount = 0;
    start_compute_i = 0;
    act_id_wren_i = 0;
    weight_id_wren_i = 0;
    cluster_enable_i = 0;
    error_count = 0;
    weight_mcn_tag_target_y = -1;
    weight_mcn_tag_target_x = -1;
    act_mcn_tag_target_y = -1;
    act_mcn_tag_target_x = -1;
    act_id_scan_i = -1;
    weight_id_scan_i = -1;

    // Cluster config
    ctrl_acount = 5;
    ctrl_wcount = 3;

    // Reset
    #(CLK_PERIOD*2);
    nrst = 1;
    #(CLK_PERIOD*2);
    cluster_enable_i = 1;
    
    // 1.1 Scan in multicast IDs
    // Careful: Make sure the id files do not have extra spaces
    $display("Scanning in multicast IDs for acts...");
    $write("ActID scan in order: ");
    for (int i = 0; i < numRegMulticastNetwork; i = i + 1) begin
        scan_file = $fscanf(act_id_file, "%d", act_id_scan_i);
        $write("%d ", act_id_scan_i);
        #(CLK_PERIOD);
    end
    $write("\n");
    act_id_wren_i = 1;
    #(CLK_PERIOD)
    act_id_wren_i = 0;
    $display("Scanning in multicast IDs for weights...");
    $write("WeightID scan in order: ");
    for (int i = 0; i < numRegMulticastNetwork; i = i + 1) begin
        scan_file = $fscanf(weight_id_file, "%d", weight_id_scan_i);
        $write("%d ", weight_id_scan_i);
        #(CLK_PERIOD);
    end
    $write("\n");
    weight_id_wren_i = 1;
    #(CLK_PERIOD);
    weight_id_wren_i = 0;

    // 2. Load in weights and activations
    // This testbench acts as a surrogate load and config controller for now.
    // The tag order files tell the testbench in what order to write what's present in the memory.
    $display("Loading in weights...");
    while(!$feof(weights_tag_order_file)) begin
        scan_file = $fscanf(weights_tag_order_file, "%d", weight_mcn_tag_target_y);
        scan_file = $fscanf(weights_tag_order_file, "%d", weight_mcn_tag_target_x);

        for (int i = 0; i < ctrl_wcount; i = i + 1) begin
            scan_file = $fscanf(w_file, "%d", w_data_i);
            $display("Wrote weight %d to tag (%d,%d)",w_data_i,weight_mcn_tag_target_x,weight_mcn_tag_target_y);
            
            #(CLK_PERIOD);
        end
    end
    weight_mcn_tag_target_y = -1;
    weight_mcn_tag_target_x = -1;

    $display("Loading in acts...");
    while(!$feof(acts_tag_order_file)) begin
        scan_file = $fscanf(acts_tag_order_file, "%d", act_mcn_tag_target_y);
        scan_file = $fscanf(acts_tag_order_file, "%d", act_mcn_tag_target_x);

        for (int i = 0; i < ctrl_acount; i = i + 1) begin
            scan_file = $fscanf(a_file, "%d", a_data_i);
            $display("Wrote act %d to tag (%d,%d)",a_data_i,act_mcn_tag_target_x,act_mcn_tag_target_y);
            #(CLK_PERIOD);
        end
    end
    act_mcn_tag_target_y = -1;
    act_mcn_tag_target_x = -1;
    #(CLK_PERIOD);

    // Start computation
    $display("Starting computation...");
    start_compute_i = 1;
    #(CLK_PERIOD);
    start_compute_i = 0;
    #(CLK_PERIOD*1000);

    // Verify output
    $display("Verifying output...");
    output_count = 0;
    output_element = 0;

    // Assume square everything (this is a fair assumption)
    outputDimensionX = ctrl_acount + 1 - ctrl_wcount;
    outputDimensionY = ctrl_acount + 1 - ctrl_wcount;

    for (int i = 0; i < outputDimensionY; i = i+1) begin
        for (int j = 0; j < outputDimensionX; j = j+1) begin
            scan_file = $fscanf(o_file, "%d", expected_output);
            $write("RTL %d -- %d Python", $signed(o_mem[j][i]), expected_output);
            if (o_mem[j][i] != expected_output) begin 
                $write("!!!\n");
                error_count = error_count + 1;
            end else begin
                $write("\n");
            end
        end
    end

    // Report results
    if (error_count == 0)
        $display("Test passed :) successfully!");
    else
        $display("Test failed :( successfully with %d errors", error_count);

    $finish;
end

// Timeout watchdog
initial begin
    #(CLK_PERIOD*MAX_CYCLES);
    $display("Error: Simulation timeout after %d cycles", MAX_CYCLES);
    $finish;
end

initial begin    
    $vcdpluson;
    $vcdplusmemon;     
    $vcdplusfile("wave.vpd"); 
end

endmodule