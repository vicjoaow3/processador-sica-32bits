// processador.v
// CPU 32-bit – FSM multiciclo – interface MAR/MBR_in/MBR_out/mem_enable/mem_op

module processador(
    input  wire        clock,
    input  wire        reset,         // reset síncrono
    // Interface de memória unificada (endereçada por PALAVRA)
    output reg  [31:0] MAR,
    input  wire [31:0] MBR_in,
    output reg  [31:0] MBR_out,
    output reg         mem_enable,    // 1 = acesso ativo
    output reg         mem_op,        // 0 = leitura, 1 = escrita
    // E/S mapeada
    input  wire [31:0] input_data,
    output reg  [31:0] output_data
);

    // -------- opcodes/funct --------
    localparam OP_RTYPE   = 6'h00;
    localparam OP_JMP     = 6'h02;

    localparam OP_JE      = 6'h04;
    localparam OP_JNE     = 6'h05;
    localparam OP_JG      = 6'h06;
    localparam OP_JGE     = 6'h07;

    localparam OP_LOADEXT = 6'h20;
    localparam OP_STOREEXT= 6'h2A;

    localparam OP_LOAD    = 6'h23;
    localparam OP_STORE   = 6'h2B;

    localparam OP_LCH     = 6'h0F;
    localparam OP_LCL     = 6'h0D;

    localparam OP_JL      = 6'h1E;
    localparam OP_JLE     = 6'h1F;

    localparam FUNCT_ADD  = 6'h20;
    localparam FUNCT_SUB  = 6'h22;
    localparam FUNCT_AND  = 6'h24;
    localparam FUNCT_OR   = 6'h25;
    localparam FUNCT_NOT  = 6'h2F; // unário (usa rs)
    localparam FUNCT_MUL  = 6'h18;
    localparam FUNCT_DIV  = 6'h1A;

    // -------- registradores/decod --------
    reg [31:0] PC, IR;
    wire [5:0]  opcode = IR[31:26];
    wire [4:0]  rs     = IR[25:21];
    wire [4:0]  rt     = IR[20:16];
    wire [4:0]  rd     = IR[15:11];
    wire [5:0]  funct  = IR[5:0];
    wire [15:0] imm16  = IR[15:0];
    wire [25:0] off26  = IR[25:0];

    wire signed [31:0] IMM_SEXT  = {{16{imm16[15]}}, imm16};    // p/ Load/Store/Branch (offset em PALAVRAS)
    wire        [31:0] IMM_ZEXT  = {16'b0, imm16};              // p/ LCL
    wire signed [31:0] OFF26_SEX = {{6{off26[25]}}, off26};     // JMP (26b) em PALAVRAS

    // Banco de registradores (32x32)
    wire [31:0] rs_data, rt_data;
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;

    banco_registradores rf (
        .clock (clock), .we (rf_we),
        .waddr (rf_waddr), .wdata (rf_wdata),
        .rs (rs), .rt (rt),
        .rs_data (rs_data), .rt_data (rt_data)
    );

    // ULA
    localparam ALU_ADD=3'd0, ALU_SUB=3'd1, ALU_AND=3'd2, ALU_OR=3'd3,
               ALU_NOT=3'd4, ALU_MUL=3'd5, ALU_DIV=3'd6;

    reg  [2:0]  alu_op;
    reg  [31:0] alu_a, alu_b;
    wire [31:0] alu_y;
    wire        alu_z, alu_n;

    ula ULA (.op(alu_op), .a(alu_a), .b(alu_b), .y(alu_y), .Z(alu_z), .N(alu_n));

    // Flags e endereço efetivo
    reg flagZ, flagN;
    reg [31:0] eff_addr;
    reg take_branch;

    // “next” para saída de E/S (robusto)
    reg [31:0] output_data_next;

    // -------- FSM --------
    localparam S_RESET=4'd0, S_FETCH=4'd1, S_FETCH_WAIT=4'd2, S_DECODE=4'd3,
               S_EXEC_R=4'd4, S_LCH=4'd5, S_LCL=4'd6, S_MEM_ADDR=4'd7,
               S_MEM_READ=4'd8, S_MEM_READ_WAIT=4'd9, S_MEM_WRITE=4'd10,
               S_MEM_WRITE_WAIT=4'd11, S_BRANCH=4'd12, S_JUMP=4'd13,
               S_LOADEXT=4'd14, S_STOREEXT=4'd15;

    reg [3:0] state, next_state;

    // Estado
    always @(posedge clock) begin
        if (reset) begin
            state <= S_RESET; PC <= 32'd0; IR <= 32'd0;
            flagZ <= 1'b0; flagN <= 1'b0;
            mem_enable <= 1'b0; mem_op <= 1'b0;
            MAR <= 32'd0; MBR_out <= 32'd0;
            rf_we <= 1'b0;
            output_data <= 32'd0; output_data_next <= 32'd0;
        end else begin
            state <= next_state;
            output_data <= output_data_next; // aplica “next” a cada ciclo
        end
    end

    // Controle combinacional
    always @* begin
        next_state = state;

        // defaults seguros
        rf_we = 1'b0; rf_waddr = 5'd0; rf_wdata = 32'd0;
        mem_enable = 1'b0; mem_op = 1'b0; MAR = 32'd0; MBR_out = 32'd0;
        alu_op = ALU_ADD; alu_a = rs_data; alu_b = rt_data;
        output_data_next = output_data;

        case (state)
            S_RESET: next_state = S_FETCH;

            // Busca (latência 1 ciclo)
            S_FETCH: begin
                mem_enable = 1'b1; mem_op = 1'b0; MAR = PC;
                next_state = S_FETCH_WAIT;
            end

            S_FETCH_WAIT: next_state = S_DECODE;

            S_DECODE: begin
                case (opcode)
                    OP_RTYPE:   next_state = S_EXEC_R;
                    OP_LCH:     next_state = S_LCH;
                    OP_LCL:     next_state = S_LCL;
                    OP_LOAD,
                    OP_STORE:   next_state = S_MEM_ADDR;
                    OP_LOADEXT: next_state = S_LOADEXT;
                    OP_STOREEXT:next_state = S_STOREEXT;
                    OP_JE, OP_JNE, OP_JG, OP_JGE, OP_JL, OP_JLE: next_state = S_BRANCH;
                    OP_JMP:     next_state = S_JUMP;
                    default:    next_state = S_FETCH; // NOP
                endcase
            end

            // Tipo-R
            S_EXEC_R: begin
                case (funct)
                    FUNCT_ADD: alu_op = ALU_ADD;
                    FUNCT_SUB: alu_op = ALU_SUB;
                    FUNCT_AND: alu_op = ALU_AND;
                    FUNCT_OR : alu_op = ALU_OR;
                    FUNCT_NOT: begin alu_op = ALU_NOT; alu_a = rs_data; alu_b = 32'd0; end
                    FUNCT_MUL: alu_op = ALU_MUL;
                    FUNCT_DIV: alu_op = ALU_DIV;
                    default:    alu_op = ALU_ADD;
                endcase
                rf_we = 1'b1; rf_waddr = rd; rf_wdata = alu_y;
                next_state = S_FETCH;
            end

            // LCH/LCL (usam rt_data — sem acesso hierárquico)
            S_LCH: begin
                rf_we = 1'b1; rf_waddr = rt; rf_wdata = {imm16, rt_data[15:0]};
                next_state = S_FETCH;
            end

            S_LCL: begin
                rf_we = 1'b1; rf_waddr = rt; rf_wdata = {rt_data[31:16], imm16};
                next_state = S_FETCH;
            end

            // Endereço efetivo para Load/Store: R[rs] + imm (sign-extend)
            S_MEM_ADDR: begin
                alu_op = ALU_ADD; alu_a = rs_data; alu_b = IMM_SEXT;
                next_state = (opcode == OP_LOAD) ? S_MEM_READ : S_MEM_WRITE;
            end

            // Leitura
            S_MEM_READ: begin
                mem_enable = 1'b1; mem_op = 1'b0; MAR = eff_addr;
                next_state = S_MEM_READ_WAIT;
            end

            S_MEM_READ_WAIT: begin
                rf_we = 1'b1; rf_waddr = rt; rf_wdata = MBR_in;
                next_state = S_FETCH;
            end

            // Escrita
            S_MEM_WRITE: begin
                mem_enable = 1'b1; mem_op = 1'b1; MAR = eff_addr; MBR_out = rt_data;
                next_state = S_MEM_WRITE_WAIT;
            end
            S_MEM_WRITE_WAIT: next_state = S_FETCH;

            // Desvios / salto
            S_BRANCH: next_state = S_FETCH;
            S_JUMP:   next_state = S_FETCH;

            // E/S mapeada
            S_LOADEXT: begin
                rf_we = 1'b1; rf_waddr = rt; rf_wdata = input_data;
                next_state = S_FETCH;
            end
            S_STOREEXT: begin
                // Atualiza saída via registrador “next” (robusto)
                output_data_next = rt_data;
                next_state = S_FETCH;
            end

            default: next_state = S_FETCH;
        endcase
    end

    // Atualizações síncronas (IR, PC, flags, endereço efetivo)
    always @(posedge clock) begin
        if (!reset) begin
            case (state)
                S_FETCH_WAIT: IR <= MBR_in;

                S_EXEC_R:     begin flagZ <= alu_z; flagN <= alu_n; PC <= PC + 32'd1; end
                S_LCH,
                S_LCL,
                S_MEM_READ_WAIT,
                S_MEM_WRITE_WAIT,
                S_LOADEXT,
                S_STOREEXT:   PC <= PC + 32'd1;

                S_MEM_ADDR:   eff_addr <= alu_y;

                S_BRANCH: begin
                    take_branch = 1'b0;
                    case (opcode)
                        OP_JE:   take_branch = (flagZ == 1'b1);
                        OP_JNE:  take_branch = (flagZ == 1'b0);
                        OP_JG:   take_branch = (flagN == 1'b0) && (flagZ == 1'b0);
                        OP_JGE:  take_branch = (flagN == 1'b0);
                        OP_JL:   take_branch = (flagN == 1'b1);
                        OP_JLE:  take_branch = (flagN == 1'b1) || (flagZ == 1'b1);
                    endcase
                    PC <= take_branch ? (PC + IMM_SEXT) : (PC + 32'd1);
                end

                S_JUMP:       PC <= PC + OFF26_SEX;
            endcase
        end
    end
endmodule