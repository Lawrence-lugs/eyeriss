`timescale 1ns/1ps

import accelerator_package::*;

module tb_output_scaler;

    // Parameters
    localparam numElements = 4;
    localparam elementWidth = 20;
    localparam outputWidth = 8;
    localparam fixedPointBits = 16;
    localparam shiftBits = 8;
    localparam CLK_PERIOD = 10;
    localparam numTests = 10;

    // Clock and reset
    logic clk;
    logic nrst;
    
    // DUT signals
    logic [numElements-1:0][elementWidth-1:0] wxI;
    logic [numElements-1:0][outputWidth-1:0] yO;
    cfg_oscaler_t cfg;
    
    // DUT instantiation
    output_scaler #(
        .numElements(numElements),
        .elementWidth(elementWidth),
        .outputWidth(outputWidth),
        .fixedPointBits(fixedPointBits)
    ) dut (
        .clk(clk),
        .nrst(nrst),
        .wx_i(wxI),
        .y_o(yO),
        .cfg(cfg)
    );

    integer ins,m0,outs,shifts;
    integer mistakes;

    logic [elementWidth-1:0] input_element;
    logic [elementWidth-1:0] output_element;

    // Test stimulus
    initial begin

        static string path = "../tb/output_scaler/inputs/";

        mistakes = 0;

        ins = $fopen({path, "ins.txt"}, "r");
        m0 = $fopen({path, "m0.txt"}, "r");
        outs = $fopen({path, "outs.txt"}, "r");
        shifts = $fopen({path, "shift.txt"}, "r");

        // Initialize signals
        nrst = 0;
        wxI = '0;
        cfg = '0;
        
        // Wait 100ns and release reset
        #(CLK_PERIOD*2);
        nrst = 1;
        #(CLK_PERIOD*2);
        
        for (int i = 0; i < numTests; i = i + 1) begin
            // Test Case 1: Basic scaling with no shift
            $fscanf(m0, "%d", cfg.output_scale); 
            $fscanf(shifts, "%d", cfg.output_shift); 
            $fscanf(ins, "%d", input_element); 
            $fscanf(outs, "%d", output_element); 

            for (int i = 0; i < numElements; i++) begin
                wxI[i] = input_element;  // TODO: Need to test with N elements for N lanes in this thing
                // But really, it can't be different for all the lanes.
            end
            
            // Wait for 2 clock cycles for pipeline stages
            #(CLK_PERIOD*2);
            
            // Check results
            $write("Checking yO vs expected: %d, %d",yO,output_element);
            if(yO != output_element) begin
                $display("!!!!!!!!!");
                mistakes++;
            end else begin
                $display("");
            end
        end
    
        // End simulation
        #(CLK_PERIOD*5);
        $display("Testbench completed successfully!");

        $display("Mistakes: %d", mistakes);
        if (mistakes != 0) begin
            $display("TEST FAIL");
        end else begin
            $display("TEST SUCCESS");
        end
        $finish;
    end
    
    // Task to check and display results
    task checkResults(string testName);
        $display("Input values (wxI):");
        for (int i = 0; i < numElements; i++) begin
            $display("\tElement %0d: %0h", i, wxI[i]);
        end
        
        $display("Output values (yO):");
        for (int i = 0; i < numElements; i++) begin
            $display("\tElement %0d: %0h", i, yO[i]);
        end
        
        $display("Configuration:");
        $display("\tOutput Scale: %0h", cfg.output_scale);
        $display("\tOutput Shift: %0d", cfg.output_shift);
    endtask

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Waveform dumping
    `ifdef SYNOPSYS
    initial begin
        $vcdplusfile("tb_output_scaler.vpd");
        $vcdpluson();
        $vcdplusmemon();
        $dumpvars(0);
    end
    `endif
    initial begin
        $dumpfile("tb_output_scaler.vcd");
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