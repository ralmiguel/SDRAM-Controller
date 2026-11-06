// Power-up initialization for the ISSI IS42S16320F SDRAM (datasheet pp. 21-22).
// Sequence: wait -> PRECHARGE ALL -> N x AUTO REFRESH -> LOAD MODE REGISTER -> done
//
// Every wait lasts (cycles + 1) clocks between commands, so the timing is
// slightly conservative. Defaults use the slowest value across the -5/-6/-7 grades.
module sdram_init #(
    parameter CLK_PERIOD_NS = 20,       // 50 MHz
    parameter T_POWERUP_NS  = 200000,   // 200 us; datasheet minimum is 100 us
    parameter T_RP_NS       = 18,
    parameter T_RC_NS       = 60,       // also applies to AUTO REFRESH
    parameter T_MRD_CYCLES  = 2,
    parameter REFRESH_COUNT = 8,        // datasheet minimum is 2
    // A12-10 reserved (0) | A9 burst write | A8-7 standard | A6-4 CL=2 | A3 sequential | A2-0 BL=1
    parameter [12:0] MODE_REGISTER = 13'b000_0_00_010_0_000
)(
    input  wire        clk,
    input  wire        rst,         // synchronous, active high
    output reg         done,
    output wire        cke,
    output wire        cs_n,
    output wire        ras_n,
    output wire        cas_n,
    output wire        we_n,
    output reg  [12:0] addr,
    output reg  [1:0]  ba,
    output wire [1:0]  dqm
);

    // Rounds a time up to whole clock cycles
    localparam POWERUP_CYCLES = (T_POWERUP_NS + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;
    localparam RP_CYCLES      = (T_RP_NS      + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;
    localparam RC_CYCLES      = (T_RC_NS      + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;

    // Commands: {CS#, RAS#, CAS#, WE#}
    localparam [3:0] CMD_NOP       = 4'b0111;
    localparam [3:0] CMD_PRECHARGE = 4'b0010;
    localparam [3:0] CMD_REFRESH   = 4'b0001;
    localparam [3:0] CMD_MRS       = 4'b0000;

    localparam [2:0] S_POWERUP   = 3'd0;
    localparam [2:0] S_PRECHARGE = 3'd1;
    localparam [2:0] S_WAIT_RP   = 3'd2;
    localparam [2:0] S_REFRESH   = 3'd3;
    localparam [2:0] S_WAIT_RC   = 3'd4;
    localparam [2:0] S_MRS       = 3'd5;
    localparam [2:0] S_WAIT_MRD  = 3'd6;
    localparam [2:0] S_DONE      = 3'd7;

    reg [2:0]  state;
    reg [3:0]  cmd;
    reg [15:0] timer;
    reg [7:0]  refresh_left;

    assign {cs_n, ras_n, cas_n, we_n} = cmd;
    assign cke = 1'b1;
    assign dqm = 2'b11;     // keep the data outputs masked during initialization

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_POWERUP;
            cmd          <= CMD_NOP;
            addr         <= 13'd0;
            ba           <= 2'd0;
            done         <= 1'b0;
            timer        <= POWERUP_CYCLES - 1;
            refresh_left <= 8'd0;
        end else begin
            // Default each cycle: NOP, overridden by the command states
            cmd  <= CMD_NOP;
            addr <= 13'd0;
            ba   <= 2'd0;

            case (state)
                S_POWERUP: begin
                    if (timer == 0) state <= S_PRECHARGE;
                    else            timer <= timer - 1'b1;
                end

                S_PRECHARGE: begin
                    cmd      <= CMD_PRECHARGE;
                    addr[10] <= 1'b1;           // A10 = 1 selects all banks
                    timer    <= RP_CYCLES - 1;
                    state    <= S_WAIT_RP;
                end

                S_WAIT_RP: begin
                    if (timer == 0) begin
                        refresh_left <= REFRESH_COUNT;
                        state        <= S_REFRESH;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                S_REFRESH: begin
                    cmd          <= CMD_REFRESH;
                    refresh_left <= refresh_left - 1'b1;
                    timer        <= RC_CYCLES - 1;
                    state        <= S_WAIT_RC;
                end

                S_WAIT_RC: begin
                    if (timer == 0)
                        state <= (refresh_left == 0) ? S_MRS : S_REFRESH;
                    else
                        timer <= timer - 1'b1;
                end

                S_MRS: begin
                    cmd   <= CMD_MRS;
                    addr  <= MODE_REGISTER;
                    timer <= T_MRD_CYCLES - 1;
                    state <= S_WAIT_MRD;
                end

                S_WAIT_MRD: begin
                    if (timer == 0) begin
                        done  <= 1'b1;
                        state <= S_DONE;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end

                default: state <= S_POWERUP;
            endcase
        end
    end

endmodule
