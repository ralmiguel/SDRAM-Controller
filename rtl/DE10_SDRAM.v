// Top level based on the Terasic System Builder template for the DE10-Lite.
// KEY[0] = reset, LEDR[0] = sequence finished, LEDR[1] = in reset.
// LEDR[0] only shows that the FSM finished. It does not prove the memory works.
module DE10_SDRAM(

    //////////// CLOCK //////////
    input               ADC_CLK_10,
    input               MAX10_CLK1_50,
    input               MAX10_CLK2_50,

    //////////// SDRAM //////////
    output      [12:0]  DRAM_ADDR,
    output      [1:0]   DRAM_BA,
    output              DRAM_CAS_N,
    output              DRAM_CKE,
    output              DRAM_CLK,
    output              DRAM_CS_N,
    inout       [15:0]  DRAM_DQ,
    output              DRAM_LDQM,
    output              DRAM_RAS_N,
    output              DRAM_UDQM,
    output              DRAM_WE_N,

    //////////// SEG7 //////////
    output      [7:0]   HEX0,
    output      [7:0]   HEX1,
    output      [7:0]   HEX2,
    output      [7:0]   HEX3,
    output      [7:0]   HEX4,
    output      [7:0]   HEX5,

    //////////// KEY //////////
    input       [1:0]   KEY,

    //////////// LED //////////
    output      [9:0]   LEDR,

    //////////// SW //////////
    input       [9:0]   SW
);

    // Synchronize the push button to the clock
    reg [1:0] rst_sync = 2'b11;
    always @(posedge MAX10_CLK1_50)
        rst_sync <= {rst_sync[0], ~KEY[0]};
    wire rst = rst_sync[1];

    wire done;
    wire [1:0] dqm;

    sdram_init u_init (
        .clk   (MAX10_CLK1_50),
        .rst   (rst),
        .done  (done),
        .cke   (DRAM_CKE),
        .cs_n  (DRAM_CS_N),
        .ras_n (DRAM_RAS_N),
        .cas_n (DRAM_CAS_N),
        .we_n  (DRAM_WE_N),
        .addr  (DRAM_ADDR),
        .ba    (DRAM_BA),
        .dqm   (dqm)
    );

    assign {DRAM_UDQM, DRAM_LDQM} = dqm;
    assign DRAM_CLK = ~MAX10_CLK1_50;   // simple phase shift; a PLL is the better long-term option
    assign DRAM_DQ  = 16'bz;            // no data transfers in this project
    assign LEDR     = {8'b0, rst, done};

    // The 7-segment displays are active low: keep them off
    assign HEX0 = 8'hFF;
    assign HEX1 = 8'hFF;
    assign HEX2 = 8'hFF;
    assign HEX3 = 8'hFF;
    assign HEX4 = 8'hFF;
    assign HEX5 = 8'hFF;

endmodule
