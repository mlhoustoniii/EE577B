module tb_cardinal_nic_melvin;

reg        tb_clk;
reg        tb_reset;
reg [1:0]  tb_addr;      
reg [63:0] tb_d_in;      
wire [63:0] tb_d_out;     
reg        tb_nicEn;     
reg        tb_nicWrEn;   
reg        tb_net_si;    
wire        tb_net_ri;    
reg [63:0] tb_net_di;    
wire        tb_net_so;    
reg        tb_net_ro;    
wire [63:0] tb_net_do;    
reg        tb_net_polarity;

cardinal_nic dut (
    .clk(tb_clk),
    .reset(tb_reset),
    .addr(tb_addr),                 // Selects which internal register
    .d_in(tb_d_in),                 // Packet from processor -> network
    .d_out(tb_d_out),                // Register contents -> processor
    .nicEn(tb_nicEn),                // NIC enable (if 0, d_out = 0)
    .nicWrEn(tb_nicWrEn),              // Write enable (1=store, 0=load)
    .net_si(tb_net_si),               // Router send-in: data is valid
    .net_ri(tb_net_ri),               // NIC ready-in:   buffer is empty
    .net_di(tb_net_di),               // Packet data from router
    .net_so(tb_net_so),               // NIC send-out:   data is valid
    .net_ro(tb_net_ro),               // Router ready-out: router can accept
    .net_do(tb_net_do),               // Packet data to router
    .net_polarity(tb_net_polarity) // 0=even cycle, 1=odd cycle
);

localparam packet = 64'hFFFF_FFFF_FFFF_FFFF;

task reset_dut();
    repeat (4) @(posedge tb_clk) begin
        tb_reset <= 1;
        tb_addr <= 2'b00;
        tb_d_in <= 64'h0000_0000_0000_0000;
        tb_nicEn <= 1'b0;
        tb_nicWrEn <= 1'b0;
        tb_net_ro <= 1'b0;
        tb_net_polarity <= 1'b0;
        tb_net_si <= 1'b0;
        tb_net_di <= 64'h0000_0000_0000_0000;
    end
    tb_reset <= 0;
endtask

task packet_nic_to_cpu();
    @(posedge tb_clk) begin
        tb_net_si <= 1'b1;
        tb_nicEn <= 1'b1;
        tb_net_di <= packet;
    end
    @(posedge tb_clk) begin
        tb_net_si <= 1'b0;
        tb_nicEn <= 1'b0;
    end
endtask

task packet_cpu_to_nic();
    @(posedge tb_clk) begin
        tb_nicEn <= 1'b1;
        tb_nicWrEn <= 1'b1;
        tb_net_polarity <= 1'b1;
        tb_net_ro <= 1'b1;
        tb_d_in <= packet;
    end
    @(posedge tb_clk) begin
        tb_nicEn <= 1'b0;
        tb_nicWrEn <= 1'b0;
        tb_net_ro <= 1'b0;
    end
endtask

initial begin
    tb_clk = 0;
    forever #4 tb_clk = ~tb_clk;
end

initial begin 
    reset_dut();

    packet_cpu_to_nic();
    repeat (4) @(posedge tb_clk);
    packet_cpu_to_nic();

    $stop;
end

endmodule