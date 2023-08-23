module PLL_50_35(REFERENCECLK,
                    PLLOUTCORE,
                    PLLOUTGLOBAL,
                    RESET);

inout REFERENCECLK;
input RESET;    /* To initialize the simulation properly, the RESET signal (Active Low) must be asserted at the beginning of the simulation */ 
output PLLOUTCORE;
output PLLOUTGLOBAL;

SB_PLL40_CORE PLL_50_35_inst(.REFERENCECLK(REFERENCECLK),
                               .PLLOUTCORE(PLLOUTCORE),
                               .PLLOUTGLOBAL(PLLOUTGLOBAL),
                               .EXTFEEDBACK(),
                               .DYNAMICDELAY(),
                               .RESETB(RESET),
                               .BYPASS(1'b0),
                               .LATCHINPUTVALUE(),
                               .LOCK(),
                               .SDI(),
                               .SDO(),
                               .SCLK());

//\\ Fin=12, Fout=31.5;
defparam PLL_50_35_inst.DIVR = 4'b0000;
defparam PLL_50_35_inst.DIVF = 7'b1000010;
defparam PLL_50_35_inst.DIVQ = 3'b100;
defparam PLL_50_35_inst.FILTER_RANGE = 3'b001;
defparam PLL_50_35_inst.FEEDBACK_PATH = "SIMPLE";
defparam PLL_50_35_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
defparam PLL_50_35_inst.FDA_FEEDBACK = 4'b0000;
defparam PLL_50_35_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
defparam PLL_50_35_inst.FDA_RELATIVE = 4'b0000;
defparam PLL_50_35_inst.SHIFTREG_DIV_MODE = 2'b00;
defparam PLL_50_35_inst.PLLOUT_SELECT = "GENCLK";
defparam PLL_50_35_inst.ENABLE_ICEGATE = 1'b0;

endmodule
