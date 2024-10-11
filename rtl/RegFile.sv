module RegFile
#(
    param dataSize = 8,
    param numRegister = 16
)
( 
    input clk,
    input nrst,

    input [dataSize-1:0] wr_data,

    input [$clog2(numRegister)-1:0] wr_addr,
    input [$clog2(numRegister)-1:0] rd_addr_1,
    input [$clog2(numRegister)-1:0] rd_addr_2,    
    
    input wr_en,

    output logic [dataSize-1:0] rd_data_1,
    output logic [dataSize-1:0] rd_data_2
);

// Original eyeriss uses a single-read spad, leading it to use 3 entire cycles to compute.

logic [numRegister-1:0][dataSize-1:0] registers;

always_ff @( posedge clk or negedge nrst ) begin : RegFile
    if (!nrst) begin
        foreach(registers[reg]) begin
            registers[reg] <= 0;
        end
    end else begin
        if (wr_en) begin
            registers[wr_addr] <= wr_data;
        end
    end
end

always_comb begin : CombRead
    rd_data_1 = registers[rd_addr_1];
    rd_data_2 = registers[rd_addr_2];
end

endmodule