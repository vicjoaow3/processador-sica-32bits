module banco_registradores(
    input  wire        clock,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  rs,
    input  wire [4:0]  rt,
    output wire [31:0] rs_data,
    output wire [31:0] rt_data
);
    reg [31:0] regs [0:31];

    assign rs_data = regs[rs];
    assign rt_data = regs[rt];

    always @(posedge clock) begin
        if (we) regs[waddr] <= wdata;
    end

    integer i;
    initial begin
        for (i=0; i<32; i=i+1) regs[i] = 32'd0;
    end
endmodule