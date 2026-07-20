`timescale 1ns / 1ps

module radix2_butterfly (
    // ===== NGÕ VÀO (INPUTS) =====
    // Tín hi?u A (S? ph?c: Th?c + ?o)
    input  wire signed [15:0] A_real,
    input  wire signed [15:0] A_imag,
    
    // Tín hi?u B (S? ph?c: Th?c + ?o)
    input  wire signed [15:0] B_real,
    input  wire signed [15:0] B_imag,
    
    // H? s? xoay Twiddle W_N^k (S? ph?c: Th?c + ?o)
    input  wire signed [15:0] W_real,
    input  wire signed [15:0] W_imag,

    // ===== NGÕ RA (OUTPUTS) =====
    // K?t qu? Y0 = A + B*W
    output wire signed [15:0] Y0_real,
    output wire signed [15:0] Y0_imag,
    
    // K?t qu? Y1 = A - B*W
    output wire signed [15:0] Y1_real,
    output wire signed [15:0] Y1_imag
);

    // =========================================================
    // B??C 1: PHÉP NHÂN S? PH?C (B * W)
    // Công th?c: (Br + jBi) * (Wr + jWi) = (Br*Wr - Bi*Wi) + j(Br*Wi + Bi*Wr)
    // =========================================================
    
    // L?u ý: Nhân 2 s? 16-bit s? sinh ra k?t qu? 32-bit
    wire signed [31:0] mult_rr = B_real * W_real; // Br * Wr
    wire signed [31:0] mult_ii = B_imag * W_imag; // Bi * Wi
    wire signed [31:0] mult_ri = B_real * W_imag; // Br * Wi
    wire signed [31:0] mult_ir = B_imag * W_real; // Bi * Wr

    // Tính t?ng/hi?u cho ph?n Th?c và ph?n ?o c?a (B*W) - V?n ?ang ? 32-bit
    wire signed [31:0] BW_real_32 = mult_rr - mult_ii;
    wire signed [31:0] BW_imag_32 = mult_ri + mult_ir;

    // =========================================================
    // B??C 2: CHU?N HÓA FIXED-POINT (T? Q16.16 v? l?i Q8.8)
    // =========================================================
    
    // Gi?i thích c?c k? quan tr?ng:
    // - Input là Q8.8 (8 bit nguyên, 8 bit th?p phân).
    // - Khi nhân Q8.8 v?i Q8.8, k?t qu? 32-bit s? bi?n thành chu?n Q16.16 (16 bit th?p phân).
    // - ?? ??a v? l?i chu?n 16-bit Q8.8 ban ??u, ta ph?i v?t b? 8 bit th?p phân th?a ? ?uôi (d?ch ph?i 8 bit),
    //   và l?y 16 bit tính t? ?ó tr? lên. T?c là l?y t? bit [8] ??n bit [23].
    
    wire signed [15:0] BW_real = BW_real_32[23:8];
    wire signed [15:0] BW_imag = BW_imag_32[23:8];

    // =========================================================
    // B??C 3: PHÉP TÍNH CÁNH B??M (C?NG / TR?)
    // =========================================================
    
    // Y0 = A + BW
    assign Y0_real = A_real + BW_real;
    assign Y0_imag = A_imag + BW_imag;
    
    // Y1 = A - BW
    assign Y1_real = A_real - BW_real;
    assign Y1_imag = A_imag - BW_imag;

endmodule