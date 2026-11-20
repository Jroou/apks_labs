// Модуль верхнього рівня UART (об'єднує передавач і приймач)
module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_out,
    output wire       tx_busy,
    input  wire       rx_in,
    output wire [7:0] rx_data,
    output wire       rx_valid
);

    uart_tx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx_out  (tx_out),
        .tx_busy (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx_in   (rx_in),
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );

endmodule