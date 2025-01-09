
typedef enum logic [3:0] {
    I_NOP,
    I_POINTER_RESET,
    I_LOAD_WEIGHT,
    I_LOAD_ACTIVATION,
    I_LOAD_OUTPUT,
    I_READ_ACTIVATION
} global_buffer_instruction_t;

typedef struct packed {
    logic [31:0] weight_start_addr;
    logic [31:0] activation_start_addr;
} cfg_accelerator_t; // Overridden by interface version

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
    localparam interfaceWidth = interfaceDepth*dataSize,
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
endinterface