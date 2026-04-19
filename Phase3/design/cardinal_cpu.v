/////////////////////////////////////////////////////////////////////
// Project      : EE577B Spring2026 Cardinal Processor - Phase 3
// Filename     : cardinal_cpu.v
// Description  : 64-bit Variable Data Width 4-Stage Pipelined Processor
//                Pipeline: IF -> ID -> EX/MEM -> WB
//                Implements full Cardinal ISA with forwarding, hazard
//                detection, and NIC integration.
//
// ============================================================
//  NIC INTEGRATION (EE577B Phase 3)
// ============================================================
//  Per Cardinal NIC spec "Interfacing with Processor":
//    - A memory-reference instruction goes to DMEM or the NIC based on
//      bits [16] and [17] of the effective address. Both 1 -> NIC.
//    - Two data input ports: d_in (from DMEM), nic_d_in (from NIC).
//    - Two pairs of enable outputs: memEn/memWrEn and nicEn/nicEnWr.
//    - For loads, the WB stage muxes between d_in and nic_d_in based
//      on an "is_nic" bit that travels with the instruction through
//      the EX/WB pipeline register.
//    - Load-use hazard stall logic is unchanged: a NIC load is still
//      a load-type instruction at ID time, and the NIC's d_out is
//      registered just like DMEM, so one-cycle stall still suffices.
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module cardinal_cpu (
    input              clk,
    input              reset,
    input      [0:31]  inst_in,    // Instruction from IMEM
    input      [0:63]  d_in,       // Load data from DMEM
    input      [0:63]  nic_d_in,   // Load data from NIC (memory-mapped regs)
    output     [0:31]  pc_out,     // PC for IMEM address
    output     [0:31]  addr_out,   // Effective address (DMEM index or NIC addr)
    output             memEn,      // DMEM enable      (off for NIC access)
    output             memWrEn,    // DMEM write en    (off for NIC access)
    output             nicEn,      // NIC enable       (off for DMEM access)
    output             nicEnWr,    // NIC write en     (off for DMEM access)
    output     [0:63]  d_out       // Store data (shared DMEM / NIC)
);

// ============================================================
//  REGISTER FILE  (32 x 64-bit, 2R / 1W)
// ============================================================
reg [0:63] regfile [0:31];
integer rf_idx;

// ============================================================
//  PROGRAM COUNTER
// ============================================================
wire [0:31] PC;
assign pc_out = PC;

// ============================================================
//  PIPELINE REGISTERS
// ============================================================

// --- IF/ID ---
reg [0:31]  ifid_inst;
reg         ifid_valid;

// --- ID/EX ---
reg [0:63]  idex_rA_data;
reg [0:63]  idex_rB_data;
reg [0:4]   idex_rD_addr;
reg [0:5]   idex_alu_func;
reg [0:1]   idex_ww;
reg         idex_reg_write;
reg         idex_mem_en;
reg         idex_mem_wr;
reg         idex_is_load;
reg [0:15]  idex_imm_addr;
reg         idex_valid;
reg         idex_is_rtype;

// --- EX/WB ---
reg [0:63]  exwb_alu_result;
reg [0:4]   exwb_rD_addr;
reg         exwb_reg_write;
reg         exwb_is_load;
reg         exwb_valid;
// NIC: travels with the load to tell WB where the load data came from.
// Set at ID/EX -> EX/MEM transition based on EX/MEM stage's is_nic output.
reg         exwb_is_nic;


// ============================================================
//  IF STAGE
// ============================================================
wire        branch_taken;
wire [0:31] branch_target;
wire        stall;

instruction_fetch IF_unit (
    .clk          (clk),
    .reset        (reset),
    .branch_taken (branch_taken),
    .branch_target(branch_target),
    .stall        (stall),
    .PC           (PC)
);

// IF/ID pipeline register
always @(posedge clk) begin
    if (reset) begin
        ifid_inst  <= 32'h0;
        ifid_valid <= 1'b0;
    end else if (stall) begin
        ifid_inst  <= ifid_inst;
        ifid_valid <= ifid_valid;
    end else if (branch_taken) begin
        ifid_inst  <= 32'hF000_0000; // NOP encoding
        ifid_valid <= 1'b0;
    end else begin
        ifid_inst  <= inst_in;
        ifid_valid <= 1'b1;
    end
end


// ============================================================
//  ID STAGE WIRES  (outputs of id_stage instance)
// ============================================================
wire [0:5]  id_opcode;
wire [0:4]  id_rD;
wire [0:4]  id_rA;
wire [0:4]  id_rB;
wire [0:1]  id_ww;
wire [0:5]  id_func;
wire [0:15] id_imm;

wire        id_is_rtype;
wire        id_is_load;
wire        id_is_store;
wire        id_is_beq;
wire        id_is_bneq;
wire        id_is_nop;
wire        id_is_branch;

wire        id_reg_write;
wire        id_mem_en;
wire        id_mem_wr;

wire [0:4]  rf_rdA_addr;
wire [0:4]  rf_rdB_addr;

wire        id_branch_taken_raw;
wire [0:31] id_branch_target;


// ============================================================
//  FORWARDING LOGIC
//  Must live in top level: reads pipeline regs (idex_*, exwb_*)
//  and regfile, then feeds results into id_stage as fwd_rA/rB.
// ============================================================

// Write-back data mux (needs the WB-stage load_data computed below)
wire [0:63] wb_data;   // forward-declared; assigned after load mux

// Forward-to-A qualifiers
wire fwd_exmem_to_A = idex_valid && idex_reg_write && (idex_rD_addr != 5'd0) &&
                      (idex_rD_addr == rf_rdA_addr);
wire fwd_wb_to_A    = exwb_valid && exwb_reg_write && (exwb_rD_addr != 5'd0) &&
                      (exwb_rD_addr == rf_rdA_addr) && !fwd_exmem_to_A;

// Forward-to-B qualifiers
wire fwd_exmem_to_B = idex_valid && idex_reg_write && (idex_rD_addr != 5'd0) &&
                      (idex_rD_addr == rf_rdB_addr);
wire fwd_wb_to_B    = exwb_valid && exwb_reg_write && (exwb_rD_addr != 5'd0) &&
                      (exwb_rD_addr == rf_rdB_addr) && !fwd_exmem_to_B;

// EX/MEM result (combinational, defined below after ALU)
wire [0:63] ex_alu_result;

// Async regfile reads
wire [0:63] rf_rdA_data = regfile[rf_rdA_addr];
wire [0:63] rf_rdB_data = regfile[rf_rdB_addr];

// Final forwarded values fed into id_stage
wire [0:63] fwd_rA_data = fwd_exmem_to_A ? ex_alu_result :
                          fwd_wb_to_A    ? wb_data        :
                          rf_rdA_data;

wire [0:63] fwd_rB_data = fwd_exmem_to_B ? ex_alu_result :
                          fwd_wb_to_B    ? wb_data        :
                          rf_rdB_data;


// ============================================================
//  ID STAGE INSTANTIATION
// ============================================================
id_stage ID_unit (
    .inst          (ifid_inst),
    .valid         (ifid_valid),

    .fwd_rA_data   (fwd_rA_data),
    .fwd_rB_data   (fwd_rB_data),

    .opcode        (id_opcode),
    .rD            (id_rD),
    .rA            (id_rA),
    .rB            (id_rB),
    .ww            (id_ww),
    .func          (id_func),
    .imm           (id_imm),

    .is_rtype      (id_is_rtype),
    .is_load       (id_is_load),
    .is_store      (id_is_store),
    .is_beq        (id_is_beq),
    .is_bneq       (id_is_bneq),
    .is_nop        (id_is_nop),
    .is_branch     (id_is_branch),

    .reg_write     (id_reg_write),
    .mem_en        (id_mem_en),
    .mem_wr        (id_mem_wr),

    .rf_rdA_addr   (rf_rdA_addr),
    .rf_rdB_addr   (rf_rdB_addr),

    .branch_taken  (id_branch_taken_raw),
    .branch_target (id_branch_target)
);

// Gate branch_taken with stall (stall means ID result is not yet stable)
assign branch_taken  = id_branch_taken_raw && !stall;
assign branch_target = id_branch_target;


// ============================================================
//  HAZARD DETECTION (Load-Use Stall)
//  Unchanged for NIC: NIC loads are still "is_load" at ID time and
//  their data comes back one cycle later (NIC d_out is registered),
//  same as DMEM. The existing stall covers both paths.
// ============================================================
wire load_use_hazard = idex_valid && idex_is_load &&
                       ((idex_rD_addr == rf_rdA_addr && (id_is_rtype || id_is_store || id_is_branch)) ||
                        (idex_rD_addr == rf_rdB_addr && id_is_rtype)) &&
                       (idex_rD_addr != 5'd0);

assign stall = load_use_hazard;


// ============================================================
//  ID/EX Pipeline Register
// ============================================================
always @(posedge clk) begin
    if (reset || stall) begin
        idex_rA_data   <= 64'd0;
        idex_rB_data   <= 64'd0;
        idex_rD_addr   <= 5'd0;
        idex_alu_func  <= 6'd0;
        idex_ww        <= 2'd0;
        idex_reg_write <= 1'b0;
        idex_mem_en    <= 1'b0;
        idex_mem_wr    <= 1'b0;
        idex_is_load   <= 1'b0;
        idex_imm_addr  <= 16'd0;
        idex_valid     <= 1'b0;
        idex_is_rtype  <= 1'b0;
    end else begin
        idex_rA_data   <= fwd_rA_data;
        idex_rB_data   <= fwd_rB_data;
        idex_rD_addr   <= id_rD;
        idex_alu_func  <= id_func;
        idex_ww        <= id_ww;
        idex_reg_write <= id_reg_write && !id_is_nop && !id_is_branch;
        idex_mem_en    <= id_mem_en;
        idex_mem_wr    <= id_mem_wr;
        idex_is_load   <= id_is_load;
        idex_imm_addr  <= id_imm;
        idex_valid     <= ifid_valid && !id_is_nop && !id_is_branch;
        idex_is_rtype  <= id_is_rtype;
    end
end


// ============================================================
//  EX/MEM STAGE INSTANTIATION
//  Now produces separate memEn/memWrEn and nicEn/nicEnWr based on
//  the address decode (addr[16] & addr[17]). The is_nic output is
//  captured into the EX/WB pipeline register so the WB-stage load
//  data mux knows which input port to select.
// ============================================================
wire ex_is_nic;   // EX/MEM combinational: this access targets the NIC

ex_mem_stage EX_MEM_unit (
    .rA_data    (idex_rA_data),
    .rB_data    (idex_rB_data),
    .alu_func   (idex_alu_func),
    .ww         (idex_ww),
    .is_rtype   (idex_is_rtype),
    .mem_en     (idex_mem_en),
    .mem_wr     (idex_mem_wr),
    .imm_addr   (idex_imm_addr),

    .alu_result (ex_alu_result),
    .memEn      (memEn),
    .memWrEn    (memWrEn),
    .nicEn      (nicEn),
    .nicEnWr    (nicEnWr),
    .is_nic     (ex_is_nic),
    .addr_out   (addr_out),
    .d_out      (d_out)
);


// ============================================================
//  EX/WB Pipeline Register
//  Adds exwb_is_nic: the "which device was this load from" bit.
// ============================================================
always @(posedge clk) begin
    if (reset) begin
        exwb_alu_result <= 64'd0;
        exwb_rD_addr    <= 5'd0;
        exwb_reg_write  <= 1'b0;
        exwb_is_load    <= 1'b0;
        exwb_valid      <= 1'b0;
        exwb_is_nic     <= 1'b0;
    end else begin
        exwb_alu_result <= ex_alu_result;
        exwb_rD_addr    <= idex_rD_addr;
        exwb_reg_write  <= idex_reg_write;
        exwb_is_load    <= idex_is_load;
        exwb_valid      <= idex_valid;
        exwb_is_nic     <= ex_is_nic;
    end
end


// ============================================================
//  WB STAGE
//  Load data mux: pick NIC or DMEM based on the pipelined is_nic bit.
//  The wb_data value also feeds the WB->ID forwarding path above.
// ============================================================
wire [0:63] load_data = exwb_is_nic ? nic_d_in : d_in;
assign wb_data = exwb_is_load ? load_data : exwb_alu_result;

always @(posedge clk) begin
    if (reset) begin
        for (rf_idx = 0; rf_idx < 32; rf_idx = rf_idx + 1)
            regfile[rf_idx] <= 64'd0;
    end else begin
        if (exwb_reg_write && exwb_valid && (exwb_rD_addr != 5'd0))
            regfile[exwb_rD_addr] <= wb_data;
    end
end

endmodule