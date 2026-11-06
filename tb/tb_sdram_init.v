`timescale 1ns/1ps
// Self-checking testbench. A monitor checks command order and timing on every clock.
// Override the DUT_* parameters to inject a bug and confirm the checks catch it.
module tb_sdram_init;

    parameter DUT_T_RC_NS       = 60;
    parameter DUT_REFRESH_COUNT = 8;

    localparam CLK_PERIOD_NS   = 20;
    // Worst-case limits from the IS42S16320F datasheet (-5/-6/-7 grades)
    localparam MIN_POWERUP_NS  = 100000;
    localparam MIN_T_RP_NS     = 18;
    localparam MIN_T_RC_NS     = 60;
    localparam MIN_T_MRD_CYC   = 2;
    localparam MIN_REFRESHES   = 2;
    localparam [12:0] EXPECTED_MODE = 13'h020;

    localparam [3:0] CMD_NOP = 4'b0111, CMD_PRE = 4'b0010, CMD_REF = 4'b0001, CMD_MRS = 4'b0000;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire done, cke, cs_n, ras_n, cas_n, we_n;
    wire [12:0] addr;
    wire [1:0]  ba, dqm;
    wire [3:0]  cmd = {cs_n, ras_n, cas_n, we_n};

    sdram_init #(
        .T_RC_NS       (DUT_T_RC_NS),
        .REFRESH_COUNT (DUT_REFRESH_COUNT)
    ) dut (
        .clk(clk), .rst(rst), .done(done), .cke(cke),
        .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
        .addr(addr), .ba(ba), .dqm(dqm)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    integer errors = 0;
    integer cycle = 0;
    integer last_cmd_cycle = 0;
    integer refresh_seen = 0;
    integer test_passes = 0;
    reg pre_seen = 1'b0;
    reg mrs_seen = 1'b0;
    reg done_seen = 1'b0;

    task report_error(input [8*48-1:0] msg);
        begin
            $display("[%0d ns] ERROR: %0s", $time, msg);
            errors = errors + 1;
        end
    endtask

    // ---------------- Monitor ----------------
    always @(posedge clk) begin
        if (rst) begin
            cycle = 0;
            last_cmd_cycle = 0;
            refresh_seen = 0;
            pre_seen = 1'b0;
            mrs_seen = 1'b0;
            done_seen = 1'b0;
        end else begin
            cycle = cycle + 1;

            if (cke !== 1'b1)    report_error("CKE must stay high");
            if (dqm !== 2'b11)   report_error("DQM must stay high");

            case (cmd)
                CMD_NOP: ;

                CMD_PRE: begin
                    if (pre_seen) report_error("repeated PRECHARGE");
                    if (cycle * CLK_PERIOD_NS < MIN_POWERUP_NS)
                        report_error("power-up wait too short");
                    if (addr[10] !== 1'b1) report_error("PRECHARGE without A10 high");
                    pre_seen = 1'b1;
                    last_cmd_cycle = cycle;
                end

                CMD_REF: begin
                    if (!pre_seen) report_error("REFRESH before PRECHARGE");
                    if (mrs_seen)  report_error("REFRESH after MRS");
                    if (refresh_seen == 0) begin
                        if ((cycle - last_cmd_cycle) * CLK_PERIOD_NS < MIN_T_RP_NS)
                            report_error("tRP violation");
                    end else begin
                        if ((cycle - last_cmd_cycle) * CLK_PERIOD_NS < MIN_T_RC_NS)
                            report_error("tRC violation between REFRESH");
                    end
                    refresh_seen = refresh_seen + 1;
                    last_cmd_cycle = cycle;
                end

                CMD_MRS: begin
                    if (mrs_seen) report_error("repeated MRS");
                    if (refresh_seen < MIN_REFRESHES) report_error("too few REFRESH commands");
                    if ((cycle - last_cmd_cycle) * CLK_PERIOD_NS < MIN_T_RC_NS)
                        report_error("tRC violation before MRS");
                    if (addr !== EXPECTED_MODE) report_error("wrong mode register value");
                    if (ba !== 2'b00) report_error("MRS with BA not zero");
                    mrs_seen = 1'b1;
                    last_cmd_cycle = cycle;
                end

                default: report_error("unexpected command");
            endcase

            if (done === 1'b1 && !done_seen) begin
                if (!mrs_seen) report_error("done before MRS");
                else if (cycle - last_cmd_cycle < MIN_T_MRD_CYC)
                    report_error("done before tMRD");
                done_seen = 1'b1;
            end
            if (done_seen && done !== 1'b1) report_error("done dropped");
        end
    end

    // ---------------- Stimulus ----------------
    task apply_reset;
        begin
            rst <= 1'b1;
            repeat (5) @(posedge clk);
            rst <= 1'b0;
        end
    endtask

    task wait_done_and_check;
        begin
            wait (done === 1'b1);
            repeat (50) @(posedge clk);     // nothing else may happen after done
            if (!mrs_seen) report_error("sequence ended without MRS");
            if (refresh_seen !== DUT_REFRESH_COUNT) report_error("wrong REFRESH count");
            test_passes = test_passes + 1;
        end
    endtask

    initial begin
        // Test 1: normal sequence
        apply_reset;
        wait_done_and_check;

        // Test 2: reset during the REFRESH phase must restart everything
        apply_reset;
        repeat (10020) @(posedge clk);
        apply_reset;
        wait_done_and_check;

        if (errors == 0) $display("RESULT: PASS (%0d tests)", test_passes);
        else             $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

    // A hang must also fail
    initial begin
        #2000000;
        $display("RESULT: FAIL (timeout)");
        $finish;
    end

endmodule
