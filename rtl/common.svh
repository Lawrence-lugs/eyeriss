`timescale 1ns/1ps

package accelerator_package;

    // Parameter Declarations
    parameter SHAPE_BITS = 16; 
    parameter FIXED_POINT_BITS = 16;
    parameter SHIFT_BITS = 8;
    
    // Row Stationary Accelerator Config
    typedef struct packed {
        logic [3:0][SHAPE_BITS-1:0] weight_shape; // Layer weight shape: K C FY FX
        logic [3:0][SHAPE_BITS-1:0] activation_shape; // Activation shape: B C OY OX
    
        // In using these, we must clip the fixed point multiplication output
        logic [FIXED_POINT_BITS-1:0] output_scale; // M0
        logic [SHIFT_BITS-1:0] output_shift; // 2^-n
    } cfg_rsacc_t;

    // Row Stationary Accelerator Flags
    typedef struct packed {
        logic finished,
        logic ready,
        logic running
    } flg_rsacc_t;

    // Scaler Config
    typedef struct packed {
        logic [FIXED_POINT_BITS-1:0] output_scale;
        logic [SHIFT_BITS-1:0] output_shift;
    } cfg_oscaler_t;

    typedef enum logic [3:0] {
        I_NOP,
        I_POINTER_RESET,
        I_LOAD_WEIGHT,
        I_LOAD_ACTIVATION,
        I_LOAD_OUTPUT,
        I_READ_ACTIVATION
    } global_buffer_instruction_t;

endpackage // accelerator_package 

// Config for overall accelerator
interface cfg_rsacc_itf #(
    parameter numWidth = 16;
)


    modport controllee(
        input weight_shape,
        input activation_shape
    )

endinterface

interface global_buffer_ctrl_itf #(
    parameter addrWidth = 32
);
    logic [addrWidth-1:0] weight_start_addr;
    logic [addrWidth-1:0] activation_start_addr;

    modport controllee (
        input weight_start_addr,
        input activation_start_addr
    );

    modport controller (
        output weight_start_addr,
        output activation_start_addr
    );

endinterface //global_buffer_ctrl_itf

interface global_buffer_data_itf #(
    parameter dataSize = 8,
    parameter interfaceDepth = 16,
    localparam interfaceWidth = interfaceDepth*dataSize
);    
    logic [interfaceWidth-1:0] wr_data;
    logic wr_en;
    logic [interfaceWidth-1:0] rd_data;
    logic rd_data_valid;

    modport bufferSide (
        input wr_data,
        input wr_en,
        output rd_data,
        output rd_data_valid
    );

    modport outSide (
        output wr_data,
        output wr_en,
        input rd_data,
        input rd_data_valid
    );

    // Reset function for testing.
    task reset ();
        wr_data = 0;
        wr_en = 0;
        // rd_data = 0;
        // rd_data_valid = 0;
    endtask

    // Send function for testing.
    task write (logic clk, logic [interfaceWidth-1:0] data, logic ready_i);
        wr_data = data;
        wr_en = 1;
        wait (ready_i == 1); @(posedge clk);
        wr_en = 0;
    endtask

endinterface // global_buffer_data_itf
