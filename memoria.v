module memoria #(
    parameter MEM_WORDS = 1024
)(
    input  wire        clock,
    input  wire        mem_enable,
    input  wire        mem_op,      // 0=read, 1=write
    input  wire [31:0] MAR,         // endereço por PALAVRA
    input  wire [31:0] MBR_out,     // dado para escrita
    output reg  [31:0] MBR_in       // dado lido (válido 1 ciclo após read)
);
    reg [31:0] mem [0:MEM_WORDS-1];

    // Escrita síncrona
    always @(posedge clock) begin
        if (mem_enable && mem_op) begin
            mem[MAR] <= MBR_out;
        end
    end

    // Leitura com latência de 1 ciclo
    always @(posedge clock) begin
        if (mem_enable && !mem_op) begin
            MBR_in <= mem[MAR];
        end
    end
endmodule
