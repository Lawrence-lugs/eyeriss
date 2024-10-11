module PE
#(
    parameter interfaceSize = 64,
    parameter dataSize = 8,
    parameter wSpadNReg = 16,
    parameter aSpadNReg = 16,
    parameter rfNumRegister = 16,
    localparam multResSize = dataSize*2,
    localparam macResSize = multResSize + 4
)
( 
    input clk,
    input nrst,

    /* 
    The original eyeriss uses a different interface dataSize 
    that would be a hassle to handle for the spads.
    */
    input [dataSize-1:0] weights_i,
    input [dataSize-1:0] acts_i, 
    input [macResSize-1:0] psum_i, 

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

logic [dataSize-1:0] a_reg;
logic [dataSize-1:0] w_reg;

logic [macResSize-1:0] mac_res; // Bit growth -> + $clog(maxKernelSize), use 4 for now
logic [multResSize-1:0] mult_res;
logic [multResSize-1:0] ps_reg;

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

Spad
#(
    .dataSize(dataSize),
    .numRegister(rfNumRegister)   
) w_spad // Weight Spad
(
    .clk(clk),
    .nrst(nrst),
    .wr_data(w_spad_wr_data),
    .addr(w_spad_addr),
    .wr_en(w_spad_wr_en),
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
    .wr_data(a_spad_wr_data),
    .addr(a_spad_addr),
    .wr_en(a_spad_wr_en),
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
    mac_res = mult_res + ps_reg; // Take upper bits of multiplication result
end

/* PE logic */

enum logic [2:0] {
    IDLE            = 3'b000,
    LOAD_W          = 3'b001,
    LOAD_A          = 3'b010,
    COMPUTE         = 3'b100
} state;

/*
Output position counter
*/

logic [15:0] opos;

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
        w_spad_wr_data <= 0;
        opos <= 0;
        a_spad_wr_data <= 0;
        s_spad_wr_data <= 0;
        flag_done <= 0;
        flag_psum_valid <= 0;
        psum_o <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (ctrl_loada) begin
                    // Load a_count weights into aspad sequentially
                    state <= LOAD_A;
                    a_spad_wr_en <= 1;
                    a_spad_wr_data <= acts_i;
                    a_spad_addr <= 0;
                end else begin
                    if (ctrl_loadw) begin
                        // Load w_count weights into wspad sequentially
                        state <= LOAD_W;
                        w_spad_wr_en <= 1;
                        w_spad_wr_data <= weights_i;
                        w_spad_addr <= 0;
                    end else begin
                        if (ctrl_start) begin
                            // Start compute
                            // In idle, w_addr and a_addr = 0
                            state <= COMPUTE;
                            w_reg <= w_spad_rd_data;
                            a_reg <= a_spad_rd_data;
                            ps_reg <= 0;
                            w_spad_addr <= w_spad_addr + 1;
                            a_spad_addr <= a_spad_addr + 1;
                        end else begin
                            if (ctrl_sums) begin 
                                // IDLE can also handle systolic summation of psums
                                // PE output flag_psum_valid goes into the next PE's ctrl_sums for systolic operation
                                // Bottom PE's ctrl_sums is controlled by the cluster control.
                                // Add own psum and pass up
                                psum_o <= s_spad_rd_data + psum_i;
                                flag_psum_valid <= 1;
                                if (s_spad_addr == ctrl_acount + 1 - ctrl_wcount) begin
                                    s_spad_addr <= 0;
                                end else begin
                                    s_spad_addr <= s_spad_addr + 1; // increment spad target
                                end
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end
                end
            end 
            LOAD_W: begin
                w_spad_wr_data <= weights_i;
                if (w_spad_addr == ctrl_wcount - 1) begin
                    state <= IDLE;
                    w_spad_wr_en <= 0;
                    w_spad_addr <= 0;
                end else begin
                    state <= LOAD_W;
                    w_spad_wr_en <= 1;
                    w_spad_addr <= w_spad_addr + 1;
                end
            end
            LOAD_A: begin
                a_spad_wr_data <= acts_i;
                if (a_spad_addr == ctrl_acount - 1) begin
                    state <= IDLE;
                    a_spad_wr_en <= 0;
                    a_spad_addr <= 0;
                end else begin
                    state <= LOAD_A;
                    a_spad_wr_en <= 1;
                    a_spad_addr <= a_spad_addr + 1;
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
                    ps_reg <= ps_reg + mult_res;
                    s_spad_wr_en <= 0;
                end
                if (w_spad_addr == ctrl_wcount - 1) begin // PSum is done

                    w_spad_addr <= 0;
                    a_spad_addr <= opos + 1;
                    w_reg <= w_spad_rd_data;
                    a_reg <= a_spad_rd_data;

                    if (opos == ctrl_acount + 1 - ctrl_wcount) begin // All PSums generated
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