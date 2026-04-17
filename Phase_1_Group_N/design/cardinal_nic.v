`timescale 1ns/1ps
// ============================================================
// cardinal_nic.v
// Cardinal Network Interface Component (NIC)
//
// EE 577B -- Cardinal NIC Project
//
// Purpose:
//   Provides a memory-mapped register interface between a
//   processor and the Cardinal mesh NoC router. Abstracts
//   all handshaking and virtual channel details from the
//   processor -- it simply reads and writes registers.
//
// Internal Registers (address mapped):
//   addr 2'b00 = Network Input  Channel Buffer (read-only  by proc)
//   addr 2'b01 = Network Input  Status Register(read-only  by proc)
//   addr 2'b10 = Network Output Channel Buffer (write-only by proc)
//   addr 2'b11 = Network Output Status Register(read-only  by proc)
//
// Status Register Convention:
//   1 = channel buffer is FULL  (occupied)
//   0 = channel buffer is EMPTY (available)
//
// Processor Interface Behavior (all clocked at posedge):
//   nicEn=1, nicWrEn=1, addr=2'b10 -> write d_in to output buffer
//                                     (ignored if output buffer full)
//   nicEn=1, nicWrEn=0              -> d_out = register[addr]
//   nicEn=0                         -> d_out = 64'h0
//
// Status bit placement on d_out:
//   d_out[0]    = status bit (LSB)
//   d_out[63:1] = 0 (when reading a status register)
//
// Network Output Channel (NIC -> Router):
//   net_so asserted when:
//     output buffer full AND net_ro=1 AND
//     net_polarity matches packet vc bit [63]
//   NIC injects only on correct polarity to prevent deadlock
//
// Network Input Channel (Router -> NIC):
//   net_ri = ~input_status (reflects buffer availability)
//   When net_si=1: latch net_di into input buffer at next posedge
//
// Reset Behavior (per spec):
//   net_so  = 0 (deasserted)
//   net_ri  = 1 (asserted -- buffer empty, ready to receive)
//   Both status registers = 0 (both buffers empty)
//
// Port Naming (per spec Figure 3 and Table 1):
//   Processor side: addr, d_in, d_out, nicEn, nicWrEn
//   Network side:   net_si, net_ri, net_di
//                   net_so, net_ro, net_do
//                   net_polarity
// ============================================================

module cardinal_nic (
    input  wire        clk,
    input  wire        reset,

    // ----------------------------------------------------------
    // Processor Interface
    // Behaves like a memory interface -- processor uses
    // regular load/store instructions to access NIC registers
    // ----------------------------------------------------------
    input  wire [1:0]  addr,        // Selects which internal register
    input  wire [63:0] d_in,        // Packet from processor -> network
    output reg  [63:0] d_out,       // Register contents -> processor
    input  wire        nicEn,       // NIC enable (if 0, d_out = 0)
    input  wire        nicWrEn,     // Write enable (1=store, 0=load)

    // ----------------------------------------------------------
    // Network Input Channel (Router -> NIC -> Processor)
    // Packets arrive from the router and are buffered for
    // the processor to read via load instructions
    // ----------------------------------------------------------
    input  wire        net_si,      // Router send-in: data is valid
    output wire        net_ri,      // NIC ready-in:   buffer is empty
    input  wire [63:0] net_di,      // Packet data from router

    // ----------------------------------------------------------
    // Network Output Channel (Processor -> NIC -> Router)
    // Packets from processor are buffered and injected into
    // the network on the correct virtual channel polarity
    // ----------------------------------------------------------
    output wire        net_so,      // NIC send-out:   data is valid
    input  wire        net_ro,      // Router ready-out: router can accept
    output wire [63:0] net_do,      // Packet data to router

    // ----------------------------------------------------------
    // Polarity from connected router
    // NIC uses this to inject on the correct virtual channel:
    //   Packet vc bit [63] must match net_polarity for injection
    //   This prevents deadlock by ensuring VC consistency
    // ----------------------------------------------------------
    input  wire        net_polarity // 0=even cycle, 1=odd cycle
);

    // ----------------------------------------------------------
    // Internal Registers
    //
    // net_input_buf:    holds packet received from router
    //                   waiting for processor to read
    // net_output_buf:   holds packet written by processor
    //                   waiting to be injected into network
    // input_status:     1 = input buffer full (has unread packet)
    // output_status:    1 = output buffer full (has unsent packet)
    // ----------------------------------------------------------
    reg [63:0] net_input_buf;
    reg [63:0] net_output_buf;
    reg        input_status;        // 1=full, 0=empty
    reg        output_status;       // 1=full, 0=empty

    // ----------------------------------------------------------
    // Network Input Channel Control
    //
    // net_ri: asserted when input buffer is EMPTY
    //         This is a Moore signal -- depends only on state
    //         (input_status), not on any current inputs
    //
    // Per spec: "net_ri signal can simply be regarded as an
    //            indication of whether the buffer is occupied"
    // ----------------------------------------------------------
    assign net_ri = ~input_status;

    // ----------------------------------------------------------
    // Network Output Channel Control (Mealy)
    //
    // net_so: asserted when ALL three conditions are true:
    //   1. output buffer is full (has a packet to send)
    //   2. net_ro is asserted  (router has space)
    //   3. net_polarity matches the packet's vc bit [63]
    //      (inject only on correct virtual channel per spec)
    //
    // net_do: continuously driven from output buffer
    //         (no read enable per spec buffer design rules)
    //
    // Per spec: "NIC will only inject packets into the network
    //            during either even or odd polarity to avoid
    //            network deadlock"
    // ----------------------------------------------------------
    assign net_so  = output_status
                   && net_ro
                   && (net_polarity == net_output_buf[63]);

    assign net_do  = net_output_buf;

    // ----------------------------------------------------------
    // Main Sequential Logic -- posedge clk
    //
    // Priority of operations (handled independently per channel):
    //
    // Network Input Channel:
    //   1. Reset   -> clear buffer and status
    //   2. net_si  -> latch net_di into input buffer (if empty)
    //   3. Proc load addr=2'b00 -> clear status (processor read it)
    //
    // Network Output Channel:
    //   1. Reset   -> clear buffer and status
    //   2. Proc store to addr=2'b10 -> write d_in (if not full)
    //   3. net_so  -> clear status (packet sent, router accepted)
    //
    // d_out register:
    //   Updated every cycle based on nicEn, nicWrEn, addr
    // ----------------------------------------------------------
    always @(posedge clk) begin

        if (reset) begin
            // ------------------------------------------------
            // Reset state per spec:
            //   net_so  = 0 (combinational, cleared by output_status=0)
            //   net_ri  = 1 (combinational, set   by input_status=0)
            //   both status registers = 0
            // ------------------------------------------------
            net_input_buf   <= 64'h0;
            net_output_buf  <= 64'h0;
            input_status    <= 1'b0;    // Empty -- net_ri will be 1
            output_status   <= 1'b0;    // Empty -- net_so will be 0
            d_out           <= 64'h0;

        end else begin

            // ================================================
            // NETWORK INPUT CHANNEL UPDATE
            // Router -> NIC input buffer
            // ================================================

            // When router sends data (net_si=1) AND buffer empty:
            // Latch incoming packet at this rising edge
            // Per spec: "data should be clocked into channel buffer
            //            on the next rising clock edge"
            if (net_si && !input_status) begin
                net_input_buf <= net_di;
                input_status  <= 1'b1;  // Buffer now full
            end

            // When processor reads input buffer (addr=2'b00):
            // Clear input status -- buffer is now available again
            // Only clear if processor is actually doing a valid load
            if (nicEn && !nicWrEn && (addr == 2'b00)) begin
                input_status <= 1'b0;   // Mark buffer empty after read
            end

            // ================================================
            // NETWORK OUTPUT CHANNEL UPDATE
            // Processor -> NIC output buffer -> Router
            // ================================================

            // When processor writes to output buffer:
            //   nicEn=1, nicWrEn=1, addr=2'b10, buffer empty
            // Per spec: "if channel buffer is occupied, NIC must
            //            ignore the store to prevent corruption"
            if (nicEn && nicWrEn && (addr == 2'b10) && !output_status) begin
                net_output_buf <= d_in;
                output_status  <= 1'b1; // Buffer now full
            end

            // When packet is successfully sent to router:
            //   net_so was asserted (output_status=1, net_ro=1,
            //   polarity matches) -> clear output buffer
            // net_so is combinational so we check same conditions here
            if (output_status && net_ro &&
                (net_polarity == net_output_buf[63])) begin
                output_status <= 1'b0;  // Buffer now empty
            end

            // ================================================
            // PROCESSOR READ INTERFACE (d_out register update)
            //
            // d_out is registered -- updated at posedge per spec:
            // "content of register is placed onto d_out port
            //  at the next rising clock edge"
            //
            // nicEn=0: d_out = 0 always (per spec)
            // nicEn=1, nicWrEn=0: d_out = register[addr]
            // nicEn=1, nicWrEn=1: d_out unchanged (store op)
            //
            // Status bit placement:
            //   d_out[0]    = 1-bit status value
            //   d_out[63:1] = 0 (zero-padded per spec)
            // ================================================
            if (!nicEn) begin
                // NIC disabled -- output zero
                d_out <= 64'h0;

            end else if (!nicWrEn) begin
                // Load operation -- return selected register
                case (addr)
                    2'b00: begin
                        // Network input channel buffer
                        // Read-only by processor
                        // Returns full 64-bit packet
                        d_out <= net_input_buf;
                    end

                    2'b01: begin
                        // Network input status register
                        // Read-only by processor
                        // 1 = buffer has packet waiting
                        // 0 = buffer is empty
                        d_out <= {63'h0, input_status};
                    end

                    2'b10: begin
                        // Network output channel buffer
                        // Write-only by processor -- read is undefined
                        // Per spec: "no need for processor to read"
                        // Return zeros for safety
                        d_out <= 64'h0;
                    end

                    2'b11: begin
                        // Network output status register
                        // Read-only by processor
                        // 1 = buffer occupied (processor must wait)
                        // 0 = buffer empty    (safe to write)
                        d_out <= {63'h0, output_status};
                    end

                    default: begin
                        d_out <= 64'h0;
                    end
                endcase

            end else begin
                // Store operation -- d_out unchanged
                // Processor is writing, not reading
                // d_out retains previous value
                d_out <= d_out;
            end

        end // else reset
    end // always

endmodule
