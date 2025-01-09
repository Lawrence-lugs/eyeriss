module accelerator #(
    globalBufferSize = 1024,
    globalBufferInterfaceSize = 16,
    dataSize = 8
) (
    input logic clk, nrst,

        
);
    
// Global Buffer Interface
global_buffer #(
    .dataSize(dataSize),
    .depth(globalBufferSize),
    .interfaceDepth(globalBufferInterfaceSize)
) gb (
    .clk(clk),
    .nrst(nrst),
    .addr_i(gb_addr_i),
    .wr_data_i(gb_wr_data_i),
    .wr_en(gb_wr_en),
    .rd_data_o(gb_rd_data_o),
    .valid_o(gb_valid_o)
);

endmodule