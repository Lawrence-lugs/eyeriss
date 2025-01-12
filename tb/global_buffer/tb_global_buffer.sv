`timescale 1ns/1ps

import common::*;

module tb_global_buffer();

    // timeunit 1ns;
    // timeprecision 1ps;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 12;
    parameter INTERFACE_DEPTH = 16;
    parameter DEPTH = 4096;
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic nrst;

    typedef struct packed {
        global_buffer_instruction_t inst_i;
        logic ready_o;
    } gbuf_signals_t;
    gbuf_signals_t gbuf;
    string path;
    int w_file, o_file, a_file;
    global_buffer_instruction_t inst_i;

    global_buffer_data_itf #(
        .dataSize(DATA_WIDTH),
        .interfaceDepth(INTERFACE_DEPTH)
    ) ext_data_itf_i ();

    global_buffer_data_itf #(
        .dataSize(DATA_WIDTH),
        .interfaceDepth(INTERFACE_DEPTH)
    ) obuf_data_itf_i ();

    global_buffer_ctrl_itf #(
        .addrWidth(ADDR_WIDTH)
    ) ctrl_itf_i ();

    // DUT instantiation
    global_buffer #(
        .dataSize(DATA_WIDTH),
        .depth(DEPTH),
        .addrWidth(ADDR_WIDTH),
        .interfaceDepth(INTERFACE_DEPTH)
    ) u_gb (
        .clk            (clk),
        .nrst           (nrst),
        .inst_i         (gbuf.inst_i),
        .ready_o        (gbuf.ready_o),
        .ext_data_itf_i (ext_data_itf_i.bufferSide),
        .obuf_data_itf_i(obuf_data_itf_i.bufferSide),
        .ctrl_itf_i     (ctrl_itf_i.controllee)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    logic [DATA_WIDTH-1:0] data;
    logic [ADDR_WIDTH-1:0] addr;

    // Test stimulus
    initial begin

        path = "/home/lquizon/lawrence-workspace/eyeriss/tb/global_buffer/";
        w_file = $fopen({path, "w.txt"}, "r");
        a_file = $fopen({path, "a.txt"}, "r");
        o_file = $fopen({path, "o.txt"}, "w");

        // Initialize interfaces
        // ext_data_itf_i.wr_data = 0;
        // ext_data_itf_i.wr_en = 0;
        // ext_data_itf_i.rd_data = 0;
        // ext_data_itf_i.rd_data_valid = 0;
        ext_data_itf_i.reset();

        // obuf_data_itf_i.wr_data = 0;
        // obuf_data_itf_i.wr_en = 0;
        // obuf_data_itf_i.rd_data = 0;
        // obuf_data_itf_i.rd_data_valid = 0;
        obuf_data_itf_i.reset();

        ctrl_itf_i.weight_start_addr = 0;
        ctrl_itf_i.activation_start_addr = 64;

        // Reset
        nrst = 0;
        #(CLK_PERIOD * 2);
        nrst = 1;
        #(CLK_PERIOD * 2)

        // Write weights
        $display("Writing weights...");
        while (!$feof(w_file)) begin
            if ($fscanf(w_file, "%h", data) == 1) begin
                $write("Writing data: %h into addr %h...", data, ctrl_itf_i.weight_start_addr + u_gb.weight_head);
                ext_data_itf_i.wr_data = data;
                ext_data_itf_i.wr_en = 1;
                gbuf.inst_i = I_LOAD_WEIGHT;
                $display("GOOD");
                // Wait for instruction accept
                while (!gbuf.ready_o) #(CLK_PERIOD);
                #(CLK_PERIOD);
            end
        end
        $fclose(w_file);
        $display("");

        // Write activations
        $display("Writing activations...");
        while (!$feof(a_file)) begin
            if ($fscanf(a_file, "%h", data) == 1) begin                
                $write("Writing data: %h into addr %h...", data, ctrl_itf_i.activation_start_addr + u_gb.activation_head);
                ext_data_itf_i.wr_data = data;
                ext_data_itf_i.wr_en = 1;
                gbuf.inst_i = I_LOAD_ACTIVATION;
                $display("GOOD");
                // Wait for instruction accept
                while (!gbuf.ready_o) #(CLK_PERIOD);
                #(CLK_PERIOD);
            end
        end
        inst_i = I_NOP;
        $fclose(a_file);
        $display("");

        // Reset pointer
        $display("Resetting pointer...");
        gbuf.inst_i = I_POINTER_RESET;
        // Wait for instruction accept
        while (!gbuf.ready_o) #(CLK_PERIOD);
        #(CLK_PERIOD);

        // Read activations
        $display("Reading activations...");
        for (int i = 0; i < 120; i++) begin
            ext_data_itf_i.wr_en = 0;
            gbuf.inst_i = I_READ_ACTIVATION;
            addr = ctrl_itf_i.activation_start_addr + u_gb.activation_head;
            // Wait for instruction accept
            $write("R");
            while (!gbuf.ready_o) #(CLK_PERIOD);
            #(CLK_PERIOD);
            // Wait for data valid
            $write("V");
            while (!ext_data_itf_i.rd_data_valid) #(CLK_PERIOD);
            $fwrite(o_file, "%h\n", ext_data_itf_i.rd_data);
            $display(":Read addr %h, : %h", addr, ext_data_itf_i.rd_data);
        end

        // Load from OBUF

        #(CLK_PERIOD * 5);
        $display("Simulation completed");
        $finish;
    end

    // Waveform dumping
    `ifdef SYNOPSYS
    initial begin
        $vcdplusfile("tb_global_buffer.vpd");
        $vcdpluson();
        $vcdplusmemon();
        $dumpvars(0);
    end
    `endif
    initial begin
        $dumpfile("tb_global_buffer.vcd");
        $dumpvars(0);
    end

    // Watchdog
    initial begin
        #(CLK_PERIOD * 1000);
        $display("SIMULATION TIMEOUT");
        $display("TEST FAILED");
        $finish;
    end

endmodule