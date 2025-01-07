// Standin for SRAM
// Ultra generic single-cycle memory
// Responds in 1 cycle

module RAM #(
    parameter addrWidth = 16,
    parameter dataWidth = 32,
    parameter depth = 1024 
) (
    input logic clk, nrst,
    input logic wr_en_i, // if 0, read
    input logic [addrWidth-1:0] addr_i,
    input logic [dataWidth-1:0] data_i,
    output logic [dataWidth-1:0] data_o
);

logic [dataWidth-1:0] mem [depth-1:0];
always_ff @(posedge clk, negedge nrst) begin
    if (!nrst) begin
        for (int i = 0; i < depth; i++) begin
            mem[i] <= 0;
        end
    end else begin
        if (wr_en_i) begin
            mem[addr_i] <= data_i;
        end else begin
            data_o <= mem[addr_i];
        end
    end
end
    
endmodule