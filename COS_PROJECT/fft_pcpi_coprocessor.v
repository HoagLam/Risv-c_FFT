`timescale 1ns / 1ps

module fft_pcpi_coprocessor (
    input  wire        clk,
    input  wire        resetn,

    // GIAO TIẾP VỚI CPU RISC-V
    input  wire        pcpi_valid,
    input  wire [31:0] pcpi_insn, 
    input  wire [31:0] pcpi_rs1,  
    input  wire [31:0] pcpi_rs2,  
    
    output reg         pcpi_wait, 
    output reg         pcpi_ready,
    output reg         pcpi_wr,   
    output reg  [31:0] pcpi_rd,   

    // TÍN HIỆU ĐIỀU KHIỂN NỘI BỘ
    output reg         ram_we,    
    output reg  [5:0]  ram_addr,  
    output reg  [31:0] ram_wdata, 
    output reg         fft_start  
);

    // ==========================================
    // 1. ĐỊNH NGHĨA TẬP LỆNH
    // ==========================================
    localparam OPCODE_CUSTOM = 7'b1111011; // Custom-3
    localparam FUNCT3_CALCU  = 3'b000;     // fft_calcu
    localparam FUNCT3_LOAD   = 3'b001;     // fft_load
    localparam FUNCT3_STORE  = 3'b010;     // fft_store

    // ĐÃ SỬA: Tăng lên 3-bit để thêm trạng thái an toàn
    localparam IDLE        = 3'b000;
    localparam LOAD        = 3'b001;
    localparam START_CALCU = 3'b010; // Trạng thái nhả xung Start (1 nhịp)
    localparam WAIT_CALCU  = 3'b011; // Trạng thái chờ FFT tính toán xong
    localparam STORE       = 3'b100;

    reg [2:0] state, next_state;

    wire [31:0] ram_read_data_a;
    wire [31:0] ram_read_data_b;
    wire        fft_done;
    wire        fft_we_b;
    wire [5:0]  fft_addr_b;
    wire [31:0] fft_wdata_b;

    // GIẢI MÃ LỆNH ĐỘC LẬP
    wire is_custom_inst = (pcpi_insn[6:0] == OPCODE_CUSTOM);
    wire [2:0] funct3   = pcpi_insn[14:12];
    
    wire cmd_load  = is_custom_inst & (funct3 == FUNCT3_LOAD);
    wire cmd_calcu = is_custom_inst & (funct3 == FUNCT3_CALCU);
    wire cmd_store = is_custom_inst & (funct3 == FUNCT3_STORE);

    reg [5:0] counter;
    wire [5:0] bit_reversed_addr = {counter[0], counter[1], counter[2], counter[3], counter[4], counter[5]};

    // FSM: Chuyển trạng thái và Bộ đếm địa chỉ
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= IDLE;
            counter <= 6'd0;
        end else begin
            state <= next_state;
            // Chỉ tăng địa chỉ lên 1 nấc sau khi nạp/xuất thành công 1 từ
            if (state == LOAD || state == STORE) begin
                counter <= counter + 1'b1;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (pcpi_valid) begin
                    if (cmd_load)       next_state = LOAD;
                    else if (cmd_calcu) next_state = START_CALCU; // ĐÃ SỬA
                    else if (cmd_store) next_state = STORE;
                end
            end
            LOAD:  next_state = IDLE;
            START_CALCU: next_state = WAIT_CALCU; // ĐÃ SỬA: Tự động chuyển sang chờ sau 1 nhịp
            WAIT_CALCU: if (fft_done) next_state = IDLE; // ĐÃ SỬA
            STORE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        pcpi_wait  = 1'b0;
        pcpi_ready = 1'b0;
        pcpi_wr    = 1'b0;
        ram_we     = 1'b0;
        fft_start  = 1'b0;
        ram_addr   = counter;
        ram_wdata  = 32'd0;
        pcpi_rd    = ram_read_data_a;

        case (state)
            IDLE: begin
                if (pcpi_valid && is_custom_inst) begin
                    pcpi_wait = 1'b1;
                    if (cmd_store) ram_addr = bit_reversed_addr;
                end
            end
            LOAD: begin
                pcpi_wait  = 1'b1;
                ram_we     = 1'b1;
                ram_wdata  = {pcpi_rs1[31:16], pcpi_rs1[15:0]};
                pcpi_ready = 1'b1;
            end
            START_CALCU: begin // ĐÃ SỬA
                pcpi_wait = 1'b1;
                fft_start = 1'b1; // Bắn xung start ĐÚNG 1 nhịp
            end
            WAIT_CALCU: begin // ĐÃ SỬA
                pcpi_wait = 1'b1;
                if (fft_done) pcpi_ready = 1'b1; // Nhận kết quả an toàn
            end
            STORE: begin
                pcpi_wait  = 1'b1;
                ram_addr   = bit_reversed_addr;
                pcpi_wr    = 1'b1;
                pcpi_ready = 1'b1;
            end
        endcase
    end

    // GỌI TRẠM RAM
    fft_dual_port_ram memory_block (
        .clk       (clk),
        .we_a      (ram_we),
        .addr_a    (ram_addr),
        .data_in_a (ram_wdata),
        .data_out_a(ram_read_data_a),
        .we_b      (fft_we_b),
        .addr_b    (fft_addr_b),
        .data_in_b (fft_wdata_b),
        .data_out_b(ram_read_data_b)
    );

    // GỌI LỚP BỌC FFT ENGINE WRAPPER
    fft_engine_wrapper accelerator_core (
        .clk        (clk),
        .resetn     (resetn),
        .start      (fft_start),
        .done       (fft_done),
        .ram_addr_b (fft_addr_b),
        .ram_we_b   (fft_we_b),
        .ram_wdata_b(fft_wdata_b),
        .ram_rdata_b(ram_read_data_b)
    );

endmodule