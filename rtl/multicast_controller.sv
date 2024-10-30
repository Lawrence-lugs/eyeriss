
// Controls multicast for a PE as described in eyeriss 1

// Q: How do we write the ID bits in an efficient manner?
// A: I think it ID bits should be scanned in

module multicast_controller #(
    parameter idBits = 8,
    parameter dataSize = 8
) (
    input clk, nrst,
    
    input ctrl_id_write,
    input ctrl_enable,

    input [idBits-1:0] id_wr_data_i,

    input [idBits-1:0] cast_tag_i,
    input [dataSize-1:0] cast_data_i,

    // Talk to PE
    output [dataSize-1:0] cast_data_o,
    output load
);

logic [idBits-1:0] id;

always_ff @( posedge clk or negedge nrst ) begin : idConfig
    if (!nrst) begin
        id <= 0;
    end else begin
        if (ctrl_id_write) begin
            id <= id_wr_data;
        end
end

always_comb begin : amItarget
    if (id == cast_tag_i) begin
        cast_data_o = cast_data_i;
        load = 1;
    end else begin
        cast_data_o = 0;
        load = 0;
    end    
end

endmodule