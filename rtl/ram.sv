// Standin for SRAM
// Ultra generic single-cycle memory
// Responds in 1 cycle

module RAM #(
    parameter addrWidth = 16,
    parameter dataSize = 8,
    parameter interfaceWidth = 32,
    parameter depth = 1024 // 1024 datas
) (
    input logic clk, nrst,
    input logic wr_en_i,
    input logic rd_en_i,
    input logic [addrWidth-1:0] addr_i,
    input logic [interfaceWidth-1:0] data_i,
    output logic [interfaceWidth-1:0] data_o,
    output logic valid_o
);

// Do RAMs acknowledge writes? Who knows? Maybe just ready signal?
// Not my problem yet.

logic [dataSize-1:0] mem [depth-1:0];
always_ff @(posedge clk, negedge nrst) begin
    if (!nrst) begin
        for (int i = 0; i < depth; i++) begin
            mem[i] <= 0;
        end
        valid_o <= 0;
        data_o <= 0;
    end else begin
        if (wr_en_i) begin
            for (int i = 0; i < interfaceWidth/dataSize; i++) begin
                // Little endian
                mem[addr_i + i] <= data_i[i*dataSize +: dataSize];
            end
        end 
        if (rd_en_i) begin
            for (int i = 0; i < interfaceWidth/dataSize; i++) begin
                // Little endian read
                data_o[i*dataSize +: dataSize] <= mem[addr_i + (interfaceWidth/dataSize-1-i)];
            end
            valid_o <= 1;
        end else begin
            valid_o <= 0;
        end
    end
end
    
endmodule