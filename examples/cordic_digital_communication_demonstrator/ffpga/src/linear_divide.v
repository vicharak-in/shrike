module linear_divide (
    input  wire               clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire signed [15:0]  in_y,    
    input  wire signed [15:0]  in_x,     
    input  wire                cos_neg,  
    output reg  signed [15:0]  out_z,    
    output reg                 done
);

    localparam [2:0] LAST_ITER = 3'd5;   

    localparam signed [15:0] MAX_POS = 16'sd32767;
    localparam signed [15:0] MAX_NEG = -16'sd32768;

   
    wire signed [7:0] in_x_q6 = in_x[15:8];
    wire signed [7:0] in_y_q6 = in_y[15:8];

    reg              running;
    reg [2:0]        iter;
    reg              num_neg;        
    reg signed [7:0] x_abs;         
    reg signed [7:0] y;           
    reg signed [7:0] z;            

    wire signed [7:0] x_shift = x_abs >>> iter;
    wire signed [7:0] weight  = 8'sd64 >>> iter;   

    reg signed [7:0] y_next, z_next;

    always @(*) begin
        if (y >= 0) begin
            y_next = y - x_shift;
            z_next = z + weight;
        end else begin
            y_next = y + x_shift;
            z_next = z - weight;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            iter    <= 3'd0;
            num_neg <= 1'b0;
            x_abs   <= 8'sd0;
            y       <= 8'sd0;
            z       <= 8'sd0;
            out_z   <= 16'sd0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !running) begin
                x_abs   <= in_x_q6[7] ? -in_x_q6 : in_x_q6;
                y       <= in_y_q6;
                z       <= 8'sd0;
                num_neg <= in_y[15];
                iter    <= 3'd0;
                running <= 1'b1;
            end else if (running) begin
                y <= y_next;
                z <= z_next;

                if (iter == LAST_ITER) begin
                    running <= 1'b0;
                    done    <= 1'b1;

                    if (x_abs <= 8'sd1) begin
                        
                        out_z <= (num_neg ^ cos_neg) ? MAX_NEG : MAX_POS;
                    end else if (cos_neg) begin
                        out_z <= -({{8{z_next[7]}}, z_next} <<< 8);
                    end else begin
                        out_z <= {{8{z_next[7]}}, z_next} <<< 8;
                    end
                end else begin
                    iter <= iter + 1'b1;
                end
            end
        end
    end

endmodule