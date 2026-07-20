`timescale 1ns / 1ps

module fft_dual_port_ram #(
    parameter DATA_WIDTH = 32, // 16-bit Thực + 16-bit Ảo
    parameter ADDR_WIDTH = 6   // 2^6 = 64 điểm FFT
)(
    input  wire                  clk,
    
    // --- PORT A: Giao tiếp với CPU ---
    input  wire                  we_a,       // Cờ cho phép ghi Cổng A
    input  wire [ADDR_WIDTH-1:0] addr_a,     // Địa chỉ Cổng A
    input  wire [DATA_WIDTH-1:0] data_in_a,  // Dữ liệu CPU ghi vào
    output reg  [DATA_WIDTH-1:0] data_out_a, // Dữ liệu trả về CPU đọc
    
    // --- PORT B: Giao tiếp với Lõi FFT ---
    input  wire                  we_b,       // Cờ cho phép ghi Cổng B
    input  wire [ADDR_WIDTH-1:0] addr_b,     // Địa chỉ Cổng B
    input  wire [DATA_WIDTH-1:0] data_in_b,  // Dữ liệu FFT ghi vào (Kết quả bướm)
    output reg  [DATA_WIDTH-1:0] data_out_b  // Dữ liệu nhả ra cho FFT tính toán
);

    // Khởi tạo mảng bộ nhớ (64 ô, mỗi ô 32-bit)
    reg [DATA_WIDTH-1:0] ram_block [0:(1<<ADDR_WIDTH)-1];

    // Tiến trình Cổng A (Hoạt động Đọc/Ghi đồng thời)
    always @(posedge clk) begin
        if (we_a) begin
            ram_block[addr_a] <= data_in_a;
        end
        // Luôn nhả dữ liệu ra ở chu kỳ tiếp theo (Read-after-Write)
        data_out_a <= ram_block[addr_a];
    end

    // Tiến trình Cổng B (Hoạt động Đọc/Ghi đồng thời)
    always @(posedge clk) begin
        if (we_b) begin
            ram_block[addr_b] <= data_in_b;
        end
        data_out_b <= ram_block[addr_b];
    end

endmodule