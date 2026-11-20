// Модуль передавача UART (формат 8N1: 1 старт-біт, 8 біт даних LSB first, 1 стоп-біт)
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000, // Частота тактування (50 МГц)
    parameter BAUD_RATE = 115200      // Швидкість передачі (бод/с)
)(
    input  wire       clk,      // Тактовий сигнал
    input  wire       rst_n,    // Асинхронне скидання (активний 0)
    input  wire       tx_start, // Імпульс запуску передачі
    input  wire [7:0] tx_data,  // Байт даних для передачі
    output reg        tx_out,   // Вихідна лінія TXD
    output reg        tx_busy   // Прапорець зайнятості передавача
);

    // Кількість тактів на один біт
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // Стани скінченного автомата (FSM)
    localparam [1:0] STATE_IDLE  = 2'd0,
                     STATE_START = 2'd1,
                     STATE_DATA  = 2'd2,
                     STATE_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;   // Лічильник дільника частоти
    reg [2:0]  bit_idx;   // Індекс поточного біта (0..7)
    reg [7:0]  data_reg;  // Буферний регістр для передачі

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= STATE_IDLE;
            tx_out   <= 1'b1; // У стані спокою лінія UART у "1"
            tx_busy  <= 1'b0;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx_out  <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= STATE_START;
                    end else begin
                        tx_busy  <= 1'b0;
                    end
                end

                STATE_START: begin
                    tx_out <= 1'b0; // Формування старт-біта (0)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx_out <= data_reg[bit_idx]; // Передача молодшим бітом вперед
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx_out <= 1'b1; // Формування стоп-біта (1)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        tx_busy <= 1'b0;
                        state   <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule