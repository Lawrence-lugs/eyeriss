// Saturating Combinational Multiplier
// Parametrizable Widths
// Symmetric Precision

module saturating_multiplier #(
    parameter bitWidth = 8
) (
    input signed [bitWidth-1:0] a,
    input signed [bitWidth-1:0] b,
    output logic signed [bitWidth-1:0] result
);

// I wonder if there's a more efficient way to do this.
logic signed [2*bitWidth-1:0] temp_result;

localparam maxValue = {1'b0, {(bitWidth-1){1'b1}}};  // 0111...111
localparam minValue = {1'b1, {(bitWidth-1){1'b0}}};  // 1000...000

always_comb begin 
    temp_result = a * b;
    
    if (temp_result > {{bitWidth{1'b0}}, maxValue}) begin
        // Positive overflow
        result = maxValue;
    end
    else if (temp_result < {{bitWidth{1'b0}}, minValue}) begin
        // Negative overflow
        result = minValue;
    end
    else begin
        // No overflow, take the lower bitWidth bits
        result = temp_result[bitWidth-1:0];
    end
end

endmodule