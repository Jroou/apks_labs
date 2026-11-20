`timescale 1ns / 1ps

module uart_tb;

    localparam CLK_FREQ  = 50_000_000;
    localparam BAUD_RATE = 115200;
    localparam CLK_PERIOD = 20; // 50 МГц -> період 20 нс

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_out;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid;

    // Підключення передавача до приймача (loopback)
    uart_top #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx_out  (tx_out),
        .tx_busy (tx_busy),
        .rx_in   (tx_out),   // Loopback: TXD -> RXD
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );

    // Генерація тактового сигналу 50 МГц
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Задача для відправки та перевірки одного байта
    task send_and_check(input [7:0] byte_to_send);
        begin
            @(posedge clk);
            tx_data  <= byte_to_send;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;

            // Очікування завершення прийому
            @(posedge rx_valid);
            #1;
            if (rx_data === byte_to_send) begin
                $display("[PASS] Sent: 0x%02H | Received: 0x%02H at time %0t ns",
                         byte_to_send, rx_data, $time);
            end else begin
                $display("[FAIL] Sent: 0x%02H | Received: 0x%02H at time %0t ns",
                         byte_to_send, rx_data, $time);
            end

            // Невелика пауза між кадрами
            wait (!tx_busy);
            repeat (100) @(posedge clk);
        end
    endtask

    initial begin
        // Запис осцилограм у VCD-файл для GTKWave
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);

        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        // Зняття скидання
        #100;
        rst_n = 1'b1;
        #100;

        // Тестування передачі 3 різних байтів
        send_and_check(8'h55); // 0101_0101 (чергування бітів)
        send_and_check(8'hA3); // 1010_0011
        send_and_check(8'h4B); // 0100_1011

        $display("Simulation finished.");
        $finish;
    end

endmodule