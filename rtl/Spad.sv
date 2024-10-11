module Spad
#(
    parameter dataSize = 8,
    parameter numRegister = 16
)
( 
    input clk,
    input nrst,

    input [dataSize-1:0] wr_data,
    input [$clog2(numRegister)-1:0] addr,
    input wr_en,

    output logic [dataSize-1:0] rd_data
);

logic [numRegister-1:0][dataSize-1:0] registers;

int i;

always_ff @( posedge clk or negedge nrst ) begin : Spad
    if (!nrst) begin
        for(i=0;i<numRegister;i=i+1) begin
            registers[i] <= 0;
        end
    end else begin
        if (wr_en) begin
            registers[addr] <= wr_data;
        end
    end
end

always_comb begin : CombRead
    rd_data = registers[addr];
end

endmodule