// Модуль приймача UART (формат 8N1)
module uart_rx #(
    parameter CLK_FREQ  = 50_000_000, // Частота тактування (50 МГц)
    parameter BAUD_RATE = 115200      // Швидкість прийому (бод/с)
)(
    input  wire       clk,      // Тактовий сигнал
    input  wire       rst_n,    // Асинхронне скидання (активний 0)
    input  wire       rx_in,    // Вхідна лінія RXD
    output reg  [7:0] rx_data,  // Прийнятий байт даних
    output reg        rx_valid  // Імпульс готовності прийнятого байта (1 такт)
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    // Стани скінченного автомата (FSM)
    localparam [1:0] STATE_IDLE  = 2'd0,
                     STATE_START = 2'd1,
                     STATE_DATA  = 2'd2,
                     STATE_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    // Двоступеневий синхронізатор вхідного сигналу RXD для захисту від метастабільності
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_in;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // За замовчуванням імпульс неактивний

            case (state)
                STATE_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync2 == 1'b0) begin // Виявлено спад старт-біта
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Очікування середини старт-біта для перевірки
                    if (clk_cnt < HALF_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (rx_sync2 == 1'b0) begin
                            state <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE; // Хибний старт
                        end
                    end
                end

                STATE_DATA: begin
                    // Семплювання кожного біта даних по його центру
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt            <= 16'd0;
                        shift_reg[bit_idx] <= rx_sync2;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    // Перевірка стоп-біта (1)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (rx_sync2 == 1'b1) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule