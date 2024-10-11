`timescale 1ns/1ps

module tb_PE;

// replace with your desired clk period
parameter int unsigned CLK_PERIOD = 20;

logic clk, nrst;

// Parameters
localparam int interfaceSize = 64;
localparam int dataSize = 8;
localparam int wSpadNReg = 16;
localparam int aSpadNReg = 16;

// Signals
logic [dataSize-1:0] weights_i;
logic [dataSize-1:0] acts_i;
logic [dataSize-1:0] psum_i;
logic [dataSize-1:0] psum_o;
logic ctrl_loadw;
logic ctrl_loada;
logic [7:0] ctrl_acount;
logic [7:0] ctrl_wcount;
logic ctrl_start;
logic flag_done;
logic ctrl_sums;

// Instantiate the PE module
PE #(
    .interfaceSize(interfaceSize),
    .dataSize(dataSize),
    .wSpadNReg(wSpadNReg),
    .aSpadNReg(aSpadNReg)
) pe_inst (
    .clk(clk),
    .nrst(nrst),
    .weights_i(weights_i),
    .acts_i(acts_i),
    .psum_i(psum_i),
    .psum_o(psum_o),
    .ctrl_loadw(ctrl_loadw),
    .ctrl_loada(ctrl_loada),
    .ctrl_acount(ctrl_acount),
    .ctrl_wcount(ctrl_wcount),
    .ctrl_start(ctrl_start),
    .flag_done(flag_done),
    .ctrl_sums(ctrl_sums)
);

always 
    #(CLK_PERIOD/2) clk = ~clk;

int a_f,o_f,w_f;
int i;
int cc_count;

initial begin
    $vcdplusfile("out.vpd");
    $vcdpluson;

    a_f = $fopen("/home/lquizon/lawrence-workspace/eyeriss/tb/a.txt","r");
    o_f = $fopen("/home/lquizon/lawrence-workspace/eyeriss/tb/o.txt","r");
    w_f = $fopen("/home/lquizon/lawrence-workspace/eyeriss/tb/w.txt","r");

    $display("======");

    clk = 0;
    nrst = 0;
    weights_i = 0;
    acts_i = 0;
    ctrl_loadw = 0;
    ctrl_loada = 0;
    ctrl_acount = 16;
    ctrl_wcount = 3;
    ctrl_start = 0;
    ctrl_sums = 0;

    #(CLK_PERIOD*5)
    nrst = 1;

    #(CLK_PERIOD*5)
    ctrl_loadw = 1;

    // Load a single weight every clock cycle for the next few cycles
    for(i=0;i<3;i=i+1) begin
        $fscanf(w_f,"%d",weights_i);
        #(CLK_PERIOD);    
    end

    ctrl_loadw = 0;

    #(CLK_PERIOD);

    ctrl_loada = 1;

    // Load a single activation every clock cycle for the next few cycles
    for(i=0;i<16;i=i+1) begin
        $fscanf(a_f,"%d",acts_i);
        #(CLK_PERIOD);    
    end

    ctrl_loada = 0;

    #(CLK_PERIOD);

    ctrl_start = 1;

    while(flag_done != 1 && cc_count < 1000000) begin
        #(CLK_PERIOD);
        ctrl_start = 0;
        cc_count = cc_count + 1;
    end


    // Test systolic PSUM accumulation
    #(CLK_PERIOD);
    ctrl_sums = 1;
    psum_i = 1;

    // When to stop the partial sum systolics is decided by the future cluster control.
    for (i = 0; i < ctrl_acount + 1 - ctrl_wcount ; i = i + 1 ) begin
        #(CLK_PERIOD);
    end
    ctrl_sums = 0;
    #(CLK_PERIOD*10);

    $display("done.");
    $display("======");
    $finish;
end

endmodule