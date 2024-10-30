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

    // Memory Interfaces
    input signed [dataSize-1:0] w_read_data_i,
    input signed [addrSize-1:0] w_read_addr_o,
    input signed [dataSize-1:0] a_read_data_i,
    input signed [addrSize-1:0] a_read_addr_o,
    output logic [numPeX-1:0][dataSize-1:0] outs_write_data_o,
    output logic [numPeX-1:0][dataSize-1:0] outs_write_addr_o,
    output logic outs_valid,

    // Scan inputs
    input [idSize-1:0] act_id_scan_i,
    input [idSize-1:0] weight_id_scan_i,

    // Trigger inputs
    input start_compute_i,
    input mc_controller_id_wren_i,
    input cluster_enable_i,

    // Config
    input [7:0] ctrl_acount,
    input [7:0] ctrl_wcount,
    
    // Flags
    output logic flag_done
);

// Cluster logic

// PE inputs and outputs
logic [numPeX-1:0][numPeY-1:0][dataSize-1:0]    pe_weights_i;
logic [numPeX-1:0][numPeY-1:0][dataSize-1:0]    pe_acts_i;
logic [numPeX-1:0][numPeY:0][macResSize-1:0]    pe_psum_o;
logic [numPeX-1:0][numPeY:0]                    pe_done_o;
logic [numPeX-1:0][numPeY-1:0]                  pe_flag_psum_valid;
logic [numPeX-1:0][numPeY-1:0]                  pe_w_load_en;
logic [numPeX-1:0][numPeY-1:0]                  pe_a_load_en;
logic [numPeX-1:0]                              pe_trigger_sums;

// multicast networks id scan chain
logic [numPeX*numPeY+numPeY:0][idSize-1:0] weight_mcn_id_scan_chain;
logic [numPeX*numPeY+numPeY:0][idSize-1:0] acts_mcn_id_scan_chain;

// multicast networks tag/id
logic [idSize-1:0] act_mcn_tag_target_x;
logic [idSize-1:0] weight_mcn_tag_target_x;
logic [idSize-1:0] act_mcn_tag_target_y;
logic [idSize-1:0] weight_mcn_tag_target_y;

logic [numPeY-1:0][dataSize-1:0] weight_data_x_bus;
logic [dataSize-1:0] weight_data; 

logic [numPeY-1:0][dataSize-1:0] acts_data_x_bus;
logic [dataSize-1:0] acts_data; 

// For loading phase
logic done_load;

genvar x;
genvar y;

// PE Array and X-bus multicast controllers
generate
    for (x = 0; x < numPeX; x = x+1) begin
        for (y = 0; y < numPeY; y = y+1) begin
            PE #(
                .interfaceSize(interfaceSize),
                .dataSize(dataSize),
                .wSpadNReg(wSpadNReg),
                .aSpadNReg(aSpadNReg)
            ) u_pe (
                .clk(clk),
                .nrst(nrst),

                .weights_i(pe_weights_i[x][y]),
                .acts_i(pe_acts_i[x][y]),
                
                .psum_o(pe_psum_o[x][y+1]),
                .psum_i(pe_psum_o[x][y]),

                .ctrl_loadw(pe_w_load_en[x][y]),
                .ctrl_loada(pe_a_load_en[x][y]),
                
                .ctrl_acount(ctrl_acount),
                .ctrl_wcount(ctrl_wcount),
                
                .ctrl_start(start_compute_i),
                
                .flag_psum_valid(pe_flag_psum_valid[x][y+1]),
                .ctrl_sums(pe_flag_psum_valid[x][y]),

                .flag_done(pe_done_o[x][y])
            );

            multicast_controller #(
                .idBits(idBits),
                .dataSize(dataSize)
            ) u_weight_multicast_controller_x (
                .clk(clk),
                .nrst(nrst),
                .ctrl_id_write(mc_controller_id_wren_i),
                .ctrl_enable(cluster_enable_i),
                .id_wr_data_i(weight_mcn_id_scan_chain[y*numPeX+x]),
                .cast_tag_i(weight_mcn_tag_target_x),
                .cast_data_i(weight_data_x_bus[y]),
                .cast_data_o(pe_weights_i[x][y]),
                .load(pe_w_load_en[x][y])
            );

            multicast_controller #(
                .idBits(idBits),
                .dataSize(dataSize)
            ) u_acts_multicast_controller_x (
                .clk(clk),
                .nrst(nrst),
                .ctrl_id_write(mc_controller_id_wren_i),
                .ctrl_enable(cluster_enable_i),
                .id_wr_data_i(acts_mcn_id_scan_chain[y*numPeX+x]),
                .cast_tag_i(act_mcn_tag_target_x),
                .cast_data_i(acts_data_x_bus[y]),
                .cast_data_o(pe_acts_i[x][y]),
                .load(pe_a_load_en[x][y])
            );
             
        end

        pe_flag_psum_valid[x][0] = pe_trigger_sums[x];

    end
endgenerate

// y-bus multicast controllers
generate
    for (y = 0; y < numPeY ; y = y + 1) begin
        multicast_controller #(
            .idBits(idBits),
            .dataSize(dataSize)
        ) u_acts_multicast_controller_y (
            .clk(clk),
            .nrst(nrst),
            .ctrl_id_write(mc_controller_id_wren_i),
            .ctrl_enable(cluster_enable_i),
            .id_wr_data_i(acts_mcn_id_scan_chain[numPeY*numPeX+y]),
            .cast_tag_i(act_mcn_tag_target_y),
            .cast_data_i(a_read_data_i),
            .cast_data_o(acts_data_x_bus[y])
        );        

        
        multicast_controller #(
            .idBits(idBits),
            .dataSize(dataSize)
        ) u_weights_multicast_controller_y (
            .clk(clk),
            .nrst(nrst),
            .ctrl_id_write(mc_controller_id_wren_i),
            .ctrl_enable(cluster_enable_i),
            .id_wr_data_i(weight_mcn_id_scan_chain[numPeY*numPeX+y]),
            .cast_tag_i(weight_mcn_tag_target_y),
            .cast_data_i(w_read_data_i),
            .cast_data_o(weight_data_x_bus[y])
        );        
    end
endgenerate


typedef enum bit {
    S_IDLE,
    S_LOAD,
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
            if (start_load_i) begin
                state_d = S_LOAD;
            end
        end 
        S_LOAD : begin
            if (done_load) begin
                state_d = S_IDLE;
            end
        end
        S_COMPUTE : begin
            if (pe_done[0][0] == 0) begin
                state_d = S_PARTIALSUMS;
            end
        end 
        S_PARTIALSUMS : begin
            if (pe_done_o[0][numPeY-1] == 1) begin
                state_d = S_IDLE;
            end
        end
        default: ;
    endcase
end

// Outputs : All the top PE outputs
always_comb begin : outputAssign
    for (i = 0; i < numPeX; i = i + 1) begin
        outs_write_data_o[i] = pe_psum_o[i][numPeY];
    end
    outs_valid = pe_flag_psum_valid[numPeX-1][numPeY-1]; // any psum valid output on top will do
end
always_ff @( posedge clk or negedge nrsts ) begin : outputInterface
    if (!nrst) begin
        outs_write_addr_o <= 0;
    end else begin
        // Increment everytime the output was valid
        // Reset to zero upon return to idle state
        case (state)
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
        for (int i = 0; i < numPeY*numPeX; i = i+1) begin
            acts_mcn_id_scan_chain[i] <= 0;
            weight_mcn_id_scan_chain[i] <= 0;
        end
    end else begin
        for (int i = 1; i < numPeY*numPeX; i = i+1) begin // Base case is 0
            acts_mcn_id_scan_chain[i] <= acts_mcn_id_scan_chain[i-1];
            weight_mcn_id_scan_chain[i] <= weight_mcn_id_scan_chain[i-1];
        end
        acts_mcn_id_scan_chain[0] <= act_id_scan_i;
        weight_mcn_id_scan_chain[0] <= weight_id_scan_i;
    end
end

// Load state logic
always_ff @( posedge clk or negedge nrst ) begin : loadLogic
    if (!nrst) begin
        weight_mcn_tag_target_x <= 0;
        weight_mcn_tag_target_y <= 0;
        act_mcn_tag_target_x <= 0;
        act_mcn_tag_target_y <= 0; 

        // W/A input data is hardwired into the inputs of the y-multicast networks
        w_read_addr_o <= 0; 
        a_read_addr_o <= 0;

    end else begin
        case (state_d)
            S_LOAD : begin
                // Let's keep the Y tag targets at 0 for now (these control strides, see Eyeriss V1)
                weight_mcn_tag_target_y <= 0;
                act_mcn_tag_target_y <= 0;

                // TODO: Maybe we can do acts_load_done || weights_load_done to get out of the S_LOAD state
                // and keep the acts and weights loading independent of each other, not in lockstep.            

                // Tag targets are only incremented...
                weight_mcn_tag_target_x <= weight_mcn_tag_target_x + 1;
                act_mcn_tag_target_x <= acts_mcn_tag_target_x + 1;

                // Assuming the image is flattened [X][Y] in the memory
                w_read_addr_o <= w_read_addr_o + 1;
                a_read_addr_o <= a_read_addr_o + 1;
            end 
            default: begin
                w_read_addr_o <= 0;
                a_read_addr_o <= 0;
            end
        endcase
    end
end

// Compute state logic
logic cycle_count;
always_ff @( posedge clk or negedge nrst ) begin : computeLogic
    if (!nrst) begin
        ctrl_start <= 0;
        cycle_count <= 0;
    end else begin
        case (state_q)
            S_IDLE : begin
                cycle_count <= 0; 
                if (start_compute_i) begin
                    ctrl_start <= 1;
                end 
            end
            S_COMPUTE : begin
                ctrl_start <= 0;
                if (pe_done_o[0][0] == 1) begin // doesn't matter which PE is done, they're all done at the same time.
                    cycle_count <= 0;
                end else begin
                    cycle_count <= cycle_count + 1;
                end
            end
            S_PARTIALSUMS : begin
                ctrl_start <= 0;
                if (pe_done_o[0][numPeY-1] == 1) begin
                    cycle_count <= 0;
                end else begin
                    cycle_count <= cycle_count + 1;
                end
            end
            default: begin
                cycle_count <= 0;
                ctrl_start <= 0;
            end 
        endcase
    end
end

endmodule