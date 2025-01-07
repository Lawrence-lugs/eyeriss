
// This PE does not have load states
// Designed to work with multicast controller and cluster
// ctrl_loadw and ctrl_loada no longer shift the state, but instead results in a write op and address increment.

module PE
#(
    parameter dataSize = 8,
    parameter rfNumRegister = 16,
    localparam multResSize = dataSize*2,
    localparam macResSize = multResSize + 4
)
( 
    input clk,
    input nrst,

    input signed [dataSize-1:0] weights_i,
    input signed [dataSize-1:0] acts_i, 
    input signed [macResSize-1:0] psum_i, 

    output logic [macResSize-1:0] psum_o,
    output logic flag_psum_valid,

    // Controls
    input ctrl_loadw,
    input ctrl_loada,
    input ctrl_start,
    input ctrl_sums,

    //Config
    input [7:0] ctrl_acount,
    input [7:0] ctrl_wcount,

    output logic flag_done
);

/* 
The PE must be able to handle a 1D convolution on its own using the scratchpads.
*/

/* Activation Preregisters */
logic signed [dataSize-1:0] a_reg;
logic signed [dataSize-1:0] w_reg;

logic signed [macResSize-1:0] mac_res; // Bit growth -> + $clog(maxKernelSize), use 4 for now
logic signed [multResSize-1:0] mult_res;
logic signed [macResSize-1:0] ps_reg;

/* Spads instantiation */

logic [dataSize-1:0] w_spad_wr_data;
logic [$clog2(rfNumRegister)-1:0] w_spad_addr;
logic [dataSize-1:0] w_spad_rd_data;
logic w_spad_wr_en;

logic [dataSize-1:0] a_spad_wr_data;
logic [$clog2(rfNumRegister)-1:0] a_spad_addr;
logic [dataSize-1:0] a_spad_rd_data;
logic a_spad_wr_en;

logic [macResSize-1:0] s_spad_wr_data;
logic [$clog2(rfNumRegister)-1:0] s_spad_addr;
logic [macResSize-1:0] s_spad_rd_data;
logic s_spad_wr_en;

logic [15:0] opos;
logic [15:0] ocount;
assign ocount = ctrl_acount + 1 - ctrl_wcount;

Spad
#(
    .dataSize(dataSize),
    .numRegister(rfNumRegister)   
) w_spad // Weight Spad
(
    .clk(clk),
    .nrst(nrst),
    .wr_data(weights_i),
    .addr(w_spad_addr),
    .wr_en(ctrl_loadw),
    .rd_data(w_spad_rd_data)
);
Spad 
#(
    .dataSize(dataSize),
    .numRegister(rfNumRegister)
)
a_spad // Activation Spad
(
    .clk(clk),
    .nrst(nrst),
    .wr_data(acts_i),
    .addr(a_spad_addr),
    .wr_en(ctrl_loada),
    .rd_data(a_spad_rd_data)
);
Spad 
#(
    .dataSize(macResSize),
    .numRegister(rfNumRegister)  
)
s_spad // Sum Spad
(
    .clk(clk),
    .nrst(nrst),
    .wr_data(s_spad_wr_data),
    .addr(s_spad_addr),
    .wr_en(s_spad_wr_en),
    .rd_data(s_spad_rd_data)
);

always_comb begin : multAdd
    mult_res = w_reg * a_reg;
    mac_res = mult_res + ps_reg; // For now, no saturation full precision
end

/* PE logic */

enum logic {
    IDLE            = 1'b0,
    COMPUTE         = 1'b1
} state;

/* Output position counter */


always_ff @( posedge clk or negedge nrst ) begin : peFSM
    if (!nrst) begin
        a_reg <= 0;
        w_reg <= 0;
        ps_reg <= 0;
        a_spad_wr_en <= 0;
        w_spad_wr_en <= 0;
        s_spad_wr_en <= 0;
        w_spad_addr <= 0;
        a_spad_addr <= 0;
        s_spad_addr <= -1;
        opos <= 0;
        w_spad_wr_data <= 0;
        a_spad_wr_data <= 0;
        s_spad_wr_data <= 0;
        flag_done <= 0;
        flag_psum_valid <= 0;
        psum_o <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (ctrl_start) begin
                    // Start compute
                    state <= COMPUTE;
                    w_reg <= w_spad_rd_data;
                    a_reg <= a_spad_rd_data;
                    ps_reg <= 0;
                    w_spad_addr <= w_spad_addr + 1;
                    a_spad_addr <= a_spad_addr + 1;
                end else begin
                    if (ctrl_sums) begin 
                        // Systolic summing
                        psum_o <= s_spad_rd_data + psum_i;
                        s_spad_wr_data <= s_spad_rd_data + psum_i;
                        s_spad_wr_en <= 1;
                        flag_psum_valid <= 1;
                        if (s_spad_addr == ctrl_acount - ctrl_wcount) begin
                            flag_done <= 1;
                            s_spad_addr <= -1;
                        end else begin
                            flag_done <= 0;
                            s_spad_addr <= s_spad_addr + 1;
                        end
                    end else begin
                        s_spad_wr_en <= 0;
                        flag_done <= 0;                        
                        flag_psum_valid <= 0;
                        state <= IDLE;
                        // activations/weights must be loaded continuously
                        if (ctrl_loada) begin
                            // $display("PE %s: Loaded activation %d to addr %d",
                            //     $sformatf("%m"),
                            //     acts_i,
                            //     a_spad_addr
                            // );
                            a_spad_addr <= a_spad_addr + 1; 
                        end else begin
                            a_spad_addr <= 0;
                        end
                        if (ctrl_loadw) begin
                            // $display("PE %s: Loaded weight %d to addr %d",
                            //     $sformatf("%m"),
                            //     weights_i,
                            //     w_spad_addr
                            // );
                            w_spad_addr <= w_spad_addr + 1; 
                        end else begin
                            w_spad_addr <= 0;
                        end
                    end
                end
            end 
            COMPUTE: begin
                // PSReg and Writeback is in a staggered cycle (pipelining)
                if (w_spad_addr == 0) begin
                    ps_reg <= 0;
                    s_spad_addr <= s_spad_addr + 1;
                    s_spad_wr_data <= mac_res;
                    s_spad_wr_en <= 1;
                end else begin
                    ps_reg <= $signed(ps_reg) + $signed(mult_res);
                    s_spad_wr_en <= 0;
                end
                if (w_spad_addr == ctrl_wcount - 1) begin // PSum is done

                    w_spad_addr <= 0;
                    a_spad_addr <= opos + 1;
                    w_reg <= w_spad_rd_data;
                    a_reg <= a_spad_rd_data;

                    if (opos == ocount) begin // All PSums generated
                        opos <= 0;
                        state <= IDLE;
                        flag_done <= 1;
                        s_spad_addr <= 0;
                    end else begin
                        opos <= opos + 1;
                    end
                end else begin // PSum is computing
                    
                    w_spad_addr <= w_spad_addr + 1;
                    a_spad_addr <= a_spad_addr + 1;
                    w_reg <= w_spad_rd_data;
                    a_reg <= a_spad_rd_data;
                end
            end
            default: begin
                state <= IDLE;
            end 
        endcase
        
    end
end


endmodule