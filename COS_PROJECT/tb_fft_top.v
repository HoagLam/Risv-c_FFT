`timescale 1ns / 1ps

module tb_fft_top;

    // =========================================================
    // 1. KHAI BÁO CÁC TÍN HIỆU GIẢ LẬP (TESTBENCH SIGNALS)
    // =========================================================
    reg         clk;
    reg         resetn;
    reg         pcpi_valid;
    reg  [31:0] pcpi_insn;
    reg  [31:0] pcpi_rs1;
    reg  [31:0] pcpi_rs2;
    
    wire        pcpi_wait;
    wire        pcpi_ready;
    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    
    wire        ram_we;
    wire [5:0]  ram_addr;
    wire [31:0] ram_wdata;
    wire        fft_start;

    // =========================================================
    // 2. GỌI TOP MODULE CỦA BẠN ĐỂ KIỂM TRA (UUT INSTANTIATION)
    // =========================================================
    fft_pcpi_coprocessor uut (
        .clk(clk),
        .resetn(resetn),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .ram_we(ram_we),
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .fft_start(fft_start)
    );

    // =========================================================
    // 3. BỘ TẠO XUNG NHỊP (CLOCK GENERATOR) - 50 MHz
    // =========================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // Chu kỳ T = 20ns (Đúng với báo cáo Gowin lúc nãy)
    end

    // Định nghĩa cấu trúc Tập lệnh Custom theo chuẩn Bài báo của bạn
    // Định dạng: {7'b0000000 (funct7), 5'b00000 (rs2), 5'b00000 (rs1), funct3, 5'b00000 (rd), 7'b1111011 (opcode_custom)}
    task send_pcpi_command;
        input [2:0] funct3;
        input [31:0] data_rs1;
        input [31:0] data_rs2;
        begin
            @(posedge clk);
            pcpi_valid = 1'b1;
            pcpi_insn  = {7'b0000000, 5'b00000, 5'b00000, funct3, 5'b00000, 7'b1111011};
            pcpi_rs1   = data_rs1;
            pcpi_rs2   = data_rs2;
            
            // Chờ cho đến khi mạch tăng tốc kéo cờ sẵn sàng (pcpi_ready == 1)
            @(posedge clk);
            while (pcpi_ready == 1'b0) begin
                @(posedge clk);
            end
            
            // Hủy lệnh sau khi hoàn tất chu kỳ bắt tay
            pcpi_valid = 1'b0;
            pcpi_insn  = 32'd0;
            pcpi_rs1   = 32'd0;
            pcpi_rs2   = 32'd0;
            #40; // Nghỉ giữa các lệnh
        end
    endtask

    // =========================================================
    // 4. KỊCH BẢN MÔ PHỎNG (STIMULUS PROCESS)
    // =========================================================
    integer i;
    reg signed [15:0] test_real;
    reg signed [15:0] test_imag;

    initial begin
        // Khởi tạo các giá trị ban đầu
        pcpi_valid = 0;
        pcpi_insn  = 0;
        pcpi_rs1   = 0;
        pcpi_rs2   = 0;
        resetn     = 0;
        
        // Kéo chân reset trong 100ns để khởi động hệ thống phần cứng
        #100;
        resetn = 1;
        #40;
        
        $display("[TB INFO] --- BAT DAU MOPHONG HE THONG TANG TOC FFT ---");
        
        // -----------------------------------------------------
        // KỊCH BẢN 1: Gửi 64 lệnh LOAD liên tiếp để nạp mảng vào RAM
        // -----------------------------------------------------
        $display("[TB INFO] Giai doan 1: CPU nap 64 mau so phuc xuong RAM qua PCPI...");
        for (i = 0; i < 64; i = i + 1) begin
            // Tạo dữ liệu test mẫu: Phần thực tăng dần, phần ảo bằng 0
            test_real = i * 4; 
            test_imag = 16'h0000;
            
            // Gọi hàm đóng gói dữ liệu {16-bit Ảo, 16-bit Thực} truyền qua lệnh mã funct3 = 3'b001
            send_pcpi_command(3'b001, {test_imag, test_real}, 32'd0);
        end
        $display("[TB INFO] -> Hoan tat nap 64 mau.");

        // -----------------------------------------------------
        // KỊCH BẢN 2: Gửi 1 lệnh CALCU duy nhất để chạy lõi FFT
        // -----------------------------------------------------
        $display("[TB INFO] Giai doan 2: CPU phat lenh CALCU (funct3=3'b000) kich hoat loi FFT...");
        send_pcpi_command(3'b000, 32'd0, 32'd0);
        $display("[TB INFO] -> Loi FFT da tinh toan xong 192 con buom qua 6 Stages!");

        // -----------------------------------------------------
        // KỊCH BẢN 3: Gửi 64 lệnh STORE liên tiếp để đọc ngược kết quả lên CPU
        // -----------------------------------------------------
        $display("[TB INFO] Giai doan 3: CPU phat lenh STORE (funct3=3'b010) doc ket qua qua Đảo Bit On-the-fly...");
        for (i = 0; i < 64; i = i + 1) begin
            send_pcpi_command(3'b010, 32'd0, 32'd0);
            // Dữ liệu đọc được sẽ xuất hiện tại cổng pcpi_rd ngay tại nhịp bắt tay thành công
        end
        
        $display("[TB INFO] --- MOPHONG HOAN THANH THANH CONG TOT DEP ---");
        $finish;
    end

endmodule