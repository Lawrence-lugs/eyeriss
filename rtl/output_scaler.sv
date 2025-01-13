module output_scaler #(
    parameter numElements = 4,
    parameter elementWidth = 20,
    parameter outputWidth = 8,
    parameter fixedPointBits = 16
) (
    input [numElements-1:0][elementWidth-1:0] wx_i;
    output [numElements-1:0][outputWidth-1:0] y_o;

    input cfg_oscaler_t cfg;
)

localparam scaledWidth = elementWidth+fixedPointBits;

logic [numElements-1:0][scaledWidth-1:0] scaled_wx;
logic [numElements-1:0][outputWidth-1:0] scaled_wx_clipped;
logic [numElements-1:0][outputWidth-1:0] y_o_d;

// Fixed point multiplication
always_ff @( posedge clk or negedge nrst ) begin : fpMult
    if (!nrst) begin
        scaled_wx <= 0;
        y_o <= 0;
    end else begin
        for (int i = 0; i < numElements; i = i + 1) begin
            scaled_wx[i] <= scaledWidth'(wx_i[i] * cfg.output_scale[i]);
            y_o[i] <= y_o_d[i];
        end
    end
end
always_comb begin : fpMultComb
    for (int i = 0; i < numElements; i = i + 1) begin
        scaled_wx_clipped[i] = scaled_wx[i][scaledWidth-1 -: outputWidth];
        y_o_d[i] = scaled_wx_clipped[i] >> cfg.output_shift;
    end
end

endmodule