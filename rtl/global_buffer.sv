/*

" Nakakausap na global buffer "

Instructionable global buffer

Use like so:

I_LOAD_WEIGHT * M times
I_LOAD_ACTIVATION * N times
I_POINTER_RESET -- Must reset the pointers before loading output
I_LOAD_OUTPUT * O times
I_POINTER_RESET -- Must reset again before reading activations
I_READ_ACTIVATION * P times

Where M, N, O, and P are the number of times you want to load weights, activations, outputs, and read activations, respectively.

TODO: ITF read_data and read_data_valid must be combinationally connected to external interfaces.

*/

import accelerator_package::*;

module global_buffer #(
    parameter dataSize = 8,
    parameter depth = 1024,
    parameter interfaceDepth = 16,
    parameter addrWidth = $clog2(depth),
    localparam interfaceWidth = interfaceDepth*dataSize,
    localparam totalSize = depth*dataSize
) (
    input logic clk,
    input logic nrst,

    input global_buffer_instruction_t inst_i,
    output logic ready_o,
    output logic [addrWidth-1:0] obuf_rd_addr_o,
    
    // Data interfaces from outside and the accelerator
    global_buffer_data_itf.bufferSide ext_data_itf_i,
    global_buffer_data_itf.bufferSide obuf_data_itf_i,
    global_buffer_ctrl_itf.controllee ctrl_itf_i
);

typedef struct packed {
    logic wr_en;
    logic rd_en;
    logic [addrWidth-1:0] addr;
    logic [interfaceWidth-1:0] wr_data;
    logic [interfaceWidth-1:0] rd_data;
    logic valid;
} ram_interface_t;
ram_interface_t ram_interface;

// Both head pointers are relative to cfg.xx_start_addr
logic [addrWidth-1:0] activation_head;
logic [addrWidth-1:0] weight_head;

global_buffer_instruction_t current_inst;
logic busy;

RAM #(
    .addrWidth      (addrWidth),
    .dataSize       (dataSize),
    .interfaceWidth (interfaceWidth),
    .depth          (depth)
) ram (
    .clk     (clk),
    .nrst    (nrst),
    .wr_en_i (ram_interface.wr_en),
    .rd_en_i (ram_interface.rd_en),
    .addr_i  (ram_interface.addr),
    .data_i  (ram_interface.wr_data),
    .data_o  (ram_interface.rd_data),
    .valid_o (ram_interface.valid)
);

// Busy/not
always_ff @( posedge clk or negedge nrst ) begin : curInst
    if (!nrst) begin
        current_inst <= I_NOP;
        busy <= 0;
    end else begin
        if (ready_o) begin
            current_inst <= inst_i;
            busy <= (inst_i != I_NOP);
        end
    end
end
always_comb begin
    if (busy && current_inst == I_READ_ACTIVATION) begin
        ready_o = ram_interface.valid;
    end else begin
        ready_o = 1;
    end
end

// Ready decode. Required if RAM implementation takes multiple cycles.
always_ff @( posedge clk or negedge nrst ) begin : registeredParts
    if (!nrst) begin
        activation_head <= 0;
        weight_head <= 0;
    end else begin
        case (inst_i)
            I_LOAD_WEIGHT: begin
                weight_head <= weight_head + 1;
            end
            I_LOAD_ACTIVATION: begin
                activation_head <= activation_head + 1;
            end
            I_LOAD_OUTPUT: begin
                activation_head <= activation_head + 1;
            end
            I_READ_ACTIVATION: begin
                activation_head <= activation_head + 1;
            end
            I_POINTER_RESET: begin
                activation_head <= 0;
                weight_head <= 0;
            end
        endcase
    end
end

always_comb begin : instDecode
    ram_interface.wr_en = 0;
    ram_interface.rd_en = 0;
    ram_interface.addr = 0;
    ram_interface.wr_data = 0;
    ext_data_itf_i.rd_data = ram_interface.rd_data;
    ext_data_itf_i.rd_data_valid = ram_interface.valid;
    obuf_rd_addr_o = activation_head;
    case (inst_i)
        I_LOAD_WEIGHT: begin
            ram_interface.wr_en = 1;
            ram_interface.addr = weight_head + ctrl_itf_i.weight_start_addr;
            ram_interface.wr_data = ext_data_itf_i.wr_data;
        end
        I_LOAD_ACTIVATION: begin
            ram_interface.wr_en = 1;
            ram_interface.addr = activation_head + ctrl_itf_i.activation_start_addr;
            ram_interface.wr_data = ext_data_itf_i.wr_data; // Get data from external
        end
        I_LOAD_OUTPUT: begin
            ram_interface.wr_en = 1;
            ram_interface.addr = activation_head + ctrl_itf_i.activation_start_addr;
            ram_interface.wr_data = obuf_data_itf_i.wr_data; // Get data from OBUF
        end
        I_READ_ACTIVATION: begin
            ram_interface.rd_en = 1;
            ram_interface.addr = activation_head + ctrl_itf_i.activation_start_addr;
        end
    endcase     
end

endmodule