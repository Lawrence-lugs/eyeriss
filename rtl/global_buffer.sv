module global_buffer #(
    parameter dataSize = 8,
    parameter depth = 1024,
    parameter interfaceDepth = 16,
    localparam interfaceWidth = interfaceDepth*dataSize,
    localparam addrWidth = $clog2(depth),
    localparam totalSize = depth*dataSize
) (
    input logic clk,
    input logic nrst,

    input logic [addrWidth-1:0] writeAddr,
    input logic [dataSize-1:0] writeData,
    input logic writeEn,

    output logic [addrWidth-1:0] readAddr,
    output logic [dataSize-1:0] readData,
    output logic readEn
);

logic logic_name = value;
    
always_ff @( posedge clk or negedge nrst ) begin : mainMemory
    if (!nrst) begin
        
    end else begin
        
    end
end


endmodule