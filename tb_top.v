`timescale 1ns/1ps

module tb_top;
    reg  clock = 0;
    reg  reset = 1;

    // Barramento memória
    wire [31:0] MAR;
    wire [31:0] MBR_in;
    wire [31:0] MBR_out;
    wire        mem_enable;
    wire        mem_op;

    // E/S externa
    reg  [31:0] input_data;
    wire [31:0] output_data;

    // DUT
    processador dut (
        .clock(clock),
        .reset(reset),
        .MAR(MAR),
        .MBR_in(MBR_in),
        .MBR_out(MBR_out),
        .mem_enable(mem_enable),
        .mem_op(mem_op),
        .input_data(input_data),
        .output_data(output_data)
    );

    // Memória unificada
    memoria #(.MEM_WORDS(256)) ram (
        .clock(clock),
        .mem_enable(mem_enable),
        .mem_op(mem_op),
        .MAR(MAR),
        .MBR_out(MBR_out),
        .MBR_in(MBR_in)
    );

    // Clock 100MHz (10ns período)
    always #5 clock = ~clock;

    // Dumps
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);
    end

    // Carrega programa na RAM (somente 0..18 -> sem WARNING)
    task load_program;
        integer i;
        begin
            for (i=0; i<256; i=i+1) ram.mem[i] = 32'h0000_0000;
            $readmemh("program.hex", ram.mem, 0, 18);
        end
    endtask

    // Reset síncrono
    task do_reset;
        begin
            reset = 1;
            repeat (3) @(posedge clock);
            reset = 0;
        end
    endtask

    // Espera laço final (PC preso em 18 por alguns ciclos)
    task wait_final;
        integer stuck;
        begin
            stuck = 0;
            repeat (300) begin
                @(posedge clock);
                if (dut.PC == 32'd18) stuck = stuck + 1;
                else                   stuck = 0;
                if (stuck >= 4) disable wait_final;
            end
        end
    endtask

    // Impressão requerida + asserts
    task print_and_check(input integer scenario);
        reg [31:0] R0,R1,R2,R3,R4,R5;
        begin
            R0 = dut.rf.regs[0];
            R1 = dut.rf.regs[1];
            R2 = dut.rf.regs[2];
            R3 = dut.rf.regs[3];
            R4 = dut.rf.regs[4];
            R5 = dut.rf.regs[5];

            $display("\n=== RESULTADOS (cenario=%0d) ===", scenario);
            $display("Reg0=%0d Reg1=%0d Reg2=%0d Reg3=%0d Reg4=%0d Reg5=%0d",
                      R0, R1, R2, R3, R4, R5);
            $display("Mem[1]=%0d  Mem[2]=%0d  output_data=%0d",
                      ram.mem[32'd1], ram.mem[32'd2], output_data);

            // Checks segundo o enunciado (duas simulações e impressões obrigatórias)
            // BCC720: imprimir Reg0..Reg5, output_data, Mem[1], Mem[2]; cenários 10 e 20. 
            if (scenario == 10) begin
                if (ram.mem[1] !== 32'd1)   $fatal(1, "Esperado Mem[1]=1 no cenario 10");
                if (ram.mem[2] !== 32'd16)  $fatal(1, "Esperado Mem[2]=16 no cenario 10");
                if (output_data !== 32'd2)  $fatal(1, "Esperado output_data=2 no cenario 10");
            end else if (scenario == 20) begin
                if (ram.mem[1] !== (32'd20 - 32'd16)) $fatal(1, "Esperado Mem[1]=4 no cenario 20");
                if (ram.mem[2] !== 32'd15)           $fatal(1, "Esperado Mem[2]=15 no cenario 20");
                if (output_data !== 32'd1)           $fatal(1, "Esperado output_data=1 no cenario 20");
            end

            if (R5 !== 32'd16) $fatal(1, "Reg5 deveria ser 16 (R1+R2)");
            if (R4 !== (scenario - 32'd16)) $fatal(1, "Reg4 deveria ser input_data-16");

            $display("=== OK (cenario %0d) ===\n", scenario);
        end
    endtask

    task run_scenario(input integer value);
        begin
            load_program();
            do_reset();
            input_data = value;
            wait_final();
            print_and_check(value);
        end
    endtask

    initial begin
        run_scenario(10);
        run_scenario(20);
        $display("Todas as verificacoes passaram. Encerrando simulacao.");
        $finish;
    end
endmodule