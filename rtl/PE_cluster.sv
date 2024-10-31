module PE_cluster
#(
    parameter numPeX = 3,
    parameter numPeY = 3,

    // PE parameters
    parameter interfaceSize = 64,
    parameter dataSize = 8,
    parameter addrSize = 16,
    parameter wSpadNReg = 16,
    parameter aSpadNReg = 16,
    parameter rfNumRegister = 16,
    localparam multResSize = dataSize*2,
    localparam macResSize = multResSize + 4,

    // Multicast Controllers
    parameter idSize = 8,
    parameter outputWordSize = 4
)
( 
    input clk,
    input nrst,

    output logic [numPeX-1:0][macResSize-1:0] outs_write_data_o,
    output logic [addrSize-1:0] outs_write_addr_o,
    output logic outs_valid,

    // Data in
    input signed [dataSize-1:0] w_data_i,
    input signed [dataSize-1:0] a_data_i,
    input        [idSize-1:0]   act_mcn_tag_target_x,
    input        [idSize-1:0]   weight_mcn_tag_target_x,
    input        [idSize-1:0]   act_mcn_tag_target_y,
    input        [idSize-1:0]   weight_mcn_tag_target_y,

    // Scan inputs
    input [idSize-1:0] act_id_scan_i,
    input [idSize-1:0] weight_id_scan_i,
    input act_id_wren_i,
    input weight_id_wren_i,

    // Trigger inputs
    input cluster_enable_i,
    input start_compute_i,

    // Config
    input [7:0] ctrl_acount,
    input [7:0] ctrl_wcount,    
    // Flags
    output logic flag_done
);

localparam numRegMulticastNetwork = numPeY*numPeX+numPeY; // one per multicast network, one per pe, one per pe row

// PE ARRAY NETS
logic [numPeX-1:0][numPeY-1:0][dataSize-1:0]    pe_weights_i;
logic [numPeX-1:0][numPeY-1:0][dataSize-1:0]    pe_acts_i;
logic [numPeX-1:0][numPeY:0][macResSize-1:0]    pe_psum_o;
logic [numPeX-1:0][numPeY-1:0]                  pe_done_o;
logic [numPeX-1:0][numPeY:0]                    pe_flag_psum_valid;
logic [numPeX-1:0][numPeY-1:0]                  pe_w_load_en;
logic [numPeX-1:0][numPeY-1:0]                  pe_a_load_en;
logic [numPeX-1:0]                              pe_trigger_sums;

// ID SCAN CHAIN NETS
logic [numPeX*numPeY+numPeY-1:0][idSize-1:0] weight_mcn_id_scan_chain;
logic [numPeX*numPeY+numPeY-1:0][idSize-1:0] acts_mcn_id_scan_chain;

// MULTICAST NETWORK NETS
logic [numPeY-1:0][dataSize-1:0] weight_data_x_bus;
logic [dataSize-1:0] weight_data; 

logic [numPeY-1:0][dataSize-1:0] acts_data_x_bus;
logic [dataSize-1:0] acts_data; 

// PE Array and X-bus multicast controllers
genvar x;
genvar y;
generate
    for (x = 0; x < numPeX; x = x+1) begin : PeArrayX
        for (y = 0; y < numPeY; y = y+1) begin : PeArrayY
            PE #(
                .interfaceSize  (interfaceSize),
                .dataSize       (dataSize),
                .wSpadNReg      (wSpadNReg),
                .aSpadNReg      (aSpadNReg)
            ) u_pe (
                .clk            (clk),
                .nrst           (nrst),

                .weights_i      (pe_weights_i[x][y]),
                .acts_i         (pe_acts_i[x][y]),
                
                .psum_o         (pe_psum_o[x][y+1]),
                .psum_i         (pe_psum_o[x][y]),

                .ctrl_loadw     (pe_w_load_en[x][y]),
                .ctrl_loada     (pe_a_load_en[x][y]),
                
                .ctrl_acount    (ctrl_acount),
                .ctrl_wcount    (ctrl_wcount),
                
                .ctrl_start     (start_compute_i),
                
                .flag_psum_valid(pe_flag_psum_valid[x][y+1]),
                .ctrl_sums      (pe_flag_psum_valid[x][y]),

                .flag_done      (pe_done_o[x][y])
            );

            multicast_controller #(
                .idBits         (idSize),
                .dataSize       (dataSize)
            ) u_weight_multicast_controller_x (
                .clk            (clk),
                .nrst           (nrst),
                .ctrl_id_write  (weight_id_wren_i),
                .ctrl_enable    (cluster_enable_i),
                .id_wr_data_i   (weight_mcn_id_scan_chain[x*numPeY+y]),
                .cast_tag_i     (weight_mcn_tag_target_x),
                .cast_data_i    (weight_data_x_bus[y]),
                .cast_data_o    (pe_weights_i[x][y]),
                .load           (pe_w_load_en[x][y])
            );

            multicast_controller #(
                .idBits         (idSize),
                .dataSize       (dataSize)
            ) u_acts_multicast_controller_x (
                .clk            (clk),
                .nrst           (nrst),
                .ctrl_id_write  (act_id_wren_i),
                .ctrl_enable    (cluster_enable_i),
                .id_wr_data_i   (acts_mcn_id_scan_chain[x*numPeY+y]),
                .cast_tag_i     (act_mcn_tag_target_x),
                .cast_data_i    (acts_data_x_bus[y]),
                .cast_data_o    (pe_acts_i[x][y]),
                .load           (pe_a_load_en[x][y])
            );
        end

        assign pe_flag_psum_valid[x][0] = pe_trigger_sums[x];
        assign pe_psum_o[x][0] = 0;

    end
endgenerate

// y-bus multicast controllers
generate
    for (y = 0; y < numPeY ; y = y + 1) begin : YBusMulticast
        multicast_controller #(
            .idBits         (idSize),
            .dataSize       (dataSize)
        ) u_acts_multicast_controller_y (
            .clk            (clk),
            .nrst           (nrst),
            .ctrl_id_write  (act_id_wren_i),
            .ctrl_enable    (cluster_enable_i),
            .id_wr_data_i   (acts_mcn_id_scan_chain[numPeY*numPeX+y]),
            .cast_tag_i     (act_mcn_tag_target_y),
            .cast_data_i    (a_data_i),
            .cast_data_o    (acts_data_x_bus[y]),
            .load           ()
        );        
        
        multicast_controller #(
            .idBits         (idSize),
            .dataSize       (dataSize)
        ) u_weights_multicast_controller_y (
            .clk            (clk),
            .nrst           (nrst),
            .ctrl_id_write  (weight_id_wren_i),
            .ctrl_enable    (cluster_enable_i),
            .id_wr_data_i   (weight_mcn_id_scan_chain[numPeY*numPeX+y]),
            .cast_tag_i     (weight_mcn_tag_target_y),
            .cast_data_i    (w_data_i),
            .cast_data_o    (weight_data_x_bus[y]),
            .load           ()
        );        
    end
endgenerate


typedef enum logic [1:0] {
    S_IDLE,
    S_COMPUTE,
    S_PARTIALSUMS
} cluster_state_t;

cluster_state_t state_q;
cluster_state_t state_d;

always_ff @( posedge clk or negedge nrst ) begin : mainFSM_q
    if (!nrst) begin
        state_q <= S_IDLE;
    end else begin
        state_q <= state_d;
    end
end
always_comb begin : mainFSM_d
    state_d = state_q;
    case (state_q)
        S_IDLE : begin
            if (start_compute_i) begin
                state_d = S_COMPUTE;
            end 
        end
        S_COMPUTE : begin
            if (pe_done_o[0][0] == 1) begin
                state_d = S_PARTIALSUMS;
            end
        end 
        S_PARTIALSUMS : begin
            if (pe_done_o[0][numPeY-1] == 1) begin //if the topmost PE is done, we done.
                state_d = S_IDLE;
            end
        end
        default: ;
    endcase
end

// Trigger sums
logic [4:0] trigger_ctr;
always_ff @( posedge clk or negedge nrst ) begin : triggerSumCtr
    if (!nrst) begin
        pe_trigger_sums <= 0;
        trigger_ctr <= 0;
    end else begin
        for (int i = 0; i < numPeX; i = i + 1) begin
            if (state_d == S_PARTIALSUMS) begin
                if (trigger_ctr != ctrl_acount - ctrl_wcount + 1) begin
                    trigger_ctr <= trigger_ctr + 1;
                    pe_trigger_sums <= {numPeX{1'b1}};
                end else begin
                    pe_trigger_sums <= 0;
                end
            end else begin
                pe_trigger_sums <= 0;
                trigger_ctr <= 0;
            end
        end
    end
end

// Outputs : All the top PE outputs
always_comb begin : outputAssign
    for (int i = 0; i < numPeX; i = i + 1) begin
        outs_write_data_o[i] = pe_psum_o[i][numPeY];
    end // any psum valid output on top will do
end
always_ff @( posedge clk or negedge nrst ) begin : outputInterface
    if (!nrst) begin
        outs_write_addr_o <= 0;
        outs_valid <= 0;
    end else begin
        // Increment address everytime the output was valid
        outs_valid <= pe_flag_psum_valid[numPeX-1][numPeY-1];
        case (state_d)
            S_PARTIALSUMS: begin
                if (outs_valid) begin
                    outs_write_addr_o <= outs_write_addr_o + 1;
                end
            end
            default: begin
                outs_write_addr_o <= 0;
            end 
        endcase
    end
end

// ID scan chain logic
always_ff @( posedge clk or negedge nrst ) begin : idScanChain
    if (!nrst) begin
        for (int i = 0; i < numRegMulticastNetwork; i = i+1) begin
            acts_mcn_id_scan_chain[i] <= 0;
            weight_mcn_id_scan_chain[i] <= 0;
        end
    end else begin
        for (int i = 1; i < numRegMulticastNetwork; i = i+1) begin // Base case is 0
            // Scan backwards because the ids.txt is more intuitive that way
            acts_mcn_id_scan_chain[i-1] <= acts_mcn_id_scan_chain[i];
            weight_mcn_id_scan_chain[i-1] <= weight_mcn_id_scan_chain[i];
        end
        acts_mcn_id_scan_chain[numRegMulticastNetwork-1] <= act_id_scan_i;
        weight_mcn_id_scan_chain[numRegMulticastNetwork-1] <= weight_id_scan_i;
    end
end

endmodule