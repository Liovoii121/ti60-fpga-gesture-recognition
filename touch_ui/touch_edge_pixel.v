module touch_edge_pixel(input wire clk,input wire [10:0] x,input wire [9:0] y,
 input wire[4:0] feature_state,input wire [2:0] view,input wire [7:0] threshold,input wire median,
 input wire [10:0] gesture_state,
 input wire [6:0] advanced_state,
 input wire [31:0] history_ids,
 input wire [1:0] status,input wire active,input wire [9:0] tx,ty,
 output reg [23:0] color);
 (* syn_romstyle="logic" *) reg [31:0] mode_button[0:63];
 initial $readmemh("mode_button.mem",mode_button);
 wire mode_button_area=x>=408&&x<584&&y>=68&&y<110;
 wire mode_text_area=x>=430&&x<558&&y>=81&&y<97;
 wire [5:0] mode_address=((y-81)&15)*4+((x-430)>>5);
 wire mode_ink=mode_text_area&&mode_button[mode_address][31-((x-430)&31)];
 reg [8:0] label_index[0:3119];reg [31:0] labels[0:3663];reg [8:0] word_index;reg [19:0] digits[0:319];
 initial begin $readmemh("touch_ui_text_index.mem",label_index);$readmemh("touch_ui_text_dict.mem",labels);$readmemh("touch_ui_digits.mem",digits);end
 wire safe=x<800 && y<480;
 wire [11:0] addr=(advanced_state[6]?1560:0)+(safe?(y>>3)*26+(x>>5):0);
 reg [31:0] text_word;reg [4:0] text_bit;
 reg [19:0] digit_word;reg [4:0] digit_bit;reg digit_valid;
 reg [3:0] digit;reg [10:0] dx;
 always @* begin
 dx=0;digit=0;
 if(x<240)begin dx=x-200;digit=threshold/100;end
 else if(x<280)begin dx=x-240;digit=(threshold/10)%10;end
 else begin dx=x-280;digit=threshold%10;end
 end
 always @(posedge clk)begin
 word_index<=label_index[addr];text_word<=labels[{word_index,y[2:0]}];text_bit<=31-(x&31);
 digit_word<=digits[digit*32+((y-254)>>1)%32];
 digit_bit<=19-(dx>>1);digit_valid<=!advanced_state[6] && x>=200 && x<320 && y>=254 && y<318;
 end
 (* syn_romstyle="logic" *) reg [31:0] gesture_labels[0:1919];
 initial $readmemh("touch_ui_gesture.mem",gesture_labels);
 wire gesture_ready=gesture_state[10],gesture_fault=gesture_state[9],gesture_busy=gesture_state[8];
 wire gesture_seen=gesture_state[7],gesture_quality=gesture_state[6],gesture_accepted=gesture_state[5];
 wire [4:0] gesture_class=gesture_state[4:0];
 wire [4:0] gesture_line=gesture_fault?27:!gesture_ready?28:gesture_busy?25:!gesture_seen?24:
   !gesture_quality?29:gesture_class<24?gesture_class:26;
 wire result_area=x>=110 && x<366 && y>=72 && y<104;
 wire [10:0] gesture_addr=gesture_line*64+(((y-72)>>1)&15)*4+(((x-110)>>6)&3);
 reg [31:0] gesture_word;reg [4:0] gesture_bit;reg gesture_pixel;
 always @(posedge clk)begin
 gesture_word<=gesture_labels[gesture_addr];gesture_bit<=31-(((x-110)>>1)&31);gesture_pixel<=result_area;
 end
 wire [15:0] threshold_bar=threshold<=48?(threshold*16'd128)/16'd48:16'd128+((threshold-16'd48)*16'd127)/16'd207;
 wire adv=advanced_state[6];
 reg [9:0] hex_font[0:255];initial $readmemh("touch_ui_hex.mem",hex_font);
 reg [6:0] id_x;reg [3:0] id_digit;reg id_area;reg [9:0] id_word;reg [3:0] id_bit;reg id_visible;
 always @*begin
 id_x=0;id_digit=0;id_area=0;
 if(advanced_state[6]&&y>=288&&y<304)begin
 if(x>=424&&x<464)begin id_x=x-424;id_area=1;case((x-424)/10)0:id_digit=history_ids[31:28];1:id_digit=history_ids[27:24];2:id_digit=history_ids[23:20];3:id_digit=history_ids[19:16];endcase end
 else if(x>=616&&x<656)begin id_x=x-616;id_area=1;case((x-616)/10)0:id_digit=history_ids[15:12];1:id_digit=history_ids[11:8];2:id_digit=history_ids[7:4];3:id_digit=history_ids[3:0];endcase end
 end end
 always @(posedge clk)begin id_word<=hex_font[id_digit*16+((y-288)&15)];id_bit<=9-(id_x%10);id_visible<=id_area;end
 wire feature_area,feature_ink,feature_selected;
 feature_ui_overlay features(clk,x,y,feature_state,feature_area,feature_ink,feature_selected);
 wire sentence_enabled,sentence_ink,sentence_button;
 sentence_ui_overlay sentence(clk,x,y,feature_state[2:0],sentence_enabled,sentence_ink,sentence_button);
 reg selected;
 always @* begin
 color=24'h0b1220;selected=0;
 if(!adv && y>=124 && y<188)begin
 if((x>=24 && x<200)||(x>=216 && x<392)||(x>=408 && x<584)||(x>=600 && x<776))color=24'h18263b;
 selected=(view==0 && x>=24 && x<200)||(view==1 && x>=216 && x<392)||(view==2 && x>=408 && x<584)||(view==5 && x>=600 && x<776);
 if(selected)color=24'h17bda6;
 end
 if(!adv && y>=207 && y<362 && ((x>=24 && x<494)||(x>=513 && x<777)))color=24'h121f33;
 if(!adv && y>=267 && y<332 && ((x>=44 && x<107)||(x>=410 && x<473)))color=24'h253650;
 if(y>=379 && y<436)begin
 if(x>=24 && x<266)color=24'h253650;
 if(x>=282 && x<520)color=gesture_ready&&!gesture_busy&&!gesture_fault?24'h175c50:24'h253650;
 if(x>=536 && x<777)color=24'h782c39;end
 if(!adv && y>=265 && y<299 && x>=685 && x<753)color=median?24'h17bda6:24'h344864;
 if(!adv && y>=320 && y<331 && x>=130 && x<385)color=(x-130<=threshold_bar)?24'h17bda6:24'h344864;
 if(y>=20 && y<56 && x>=621 && x<777)color=status==1?24'h175c50:status==0?24'h6c531c:24'h782c39;
 if(adv)begin
  if((y>=124 && y<188)||(y>=220 && y<284)||(y>=316 && y<366))begin
   if((x>=24 && x<200)||(x>=216 && x<392)||(x>=408 && x<584)||(x>=600 && x<776))color=24'h253650;
   selected=(y<188 && ((view==3&&x<200)||(view==4&&x>=216&&x<392))) ||
    (y>=220&&y<284&&x<200&&advanced_state[5]) ||
    (y>=316&&x>=408&&x<584&&advanced_state[3]) || (y>=316&&x>=600&&advanced_state[2]);
   if(selected)color=24'h17bda6;
  end
  if(y>=270&&y<280&&x>=34&&x<190)color=advanced_state[4]?24'h17bda6:advanced_state[5]?24'hdb9f30:24'h253650;
 end
 if(y>=68 && y<110 && x>=620 && x<777)color=24'h253650;
 if(text_word[text_bit])color=selected?24'h061b20:24'he8eef8;
 if(gesture_pixel && gesture_word[gesture_bit])color=gesture_fault?24'hff7070:gesture_busy?24'h70bfff:gesture_seen&&gesture_quality?(gesture_accepted?24'h17e8a6:24'hffd070):24'he8eef8;
 if(id_visible&&id_word[id_bit])color=24'hffe080;
 if(digit_valid && digit_word[digit_bit])color=24'hf2f7ff;
 if(adv&&feature_area)color=feature_ink?24'he8eef8:feature_selected?24'h175c50:24'h253650;
 if(sentence_enabled)color=sentence_ink?24'he8eef8:sentence_button?24'h175c50:24'h0b1220;
 if(mode_button_area)color=mode_ink?24'he8eef8:24'h175c50;
 if(active && ((x>=tx && x<tx+3 && y+10>=ty && y<=ty+10)||(y>=ty && y<ty+3 && x+10>=tx && x<=tx+10)))color=24'hffff00;
 end
endmodule
