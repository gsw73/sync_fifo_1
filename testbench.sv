`define MIN(A, B) ((A) < (B) ? (A) : (B))

typedef bit [ 31:0 ] uint32_t;
typedef enum { FAIL, PASS } pf_e;

`include "my_classes.sv"

// ========================================================================

interface fifo_if #( parameter DW = 64 )( input bit clk );
    logic rst_n = 0;
    logic push = 0;
    logic [ DW - 1:0 ] data_in = 0;
    logic full;
    logic alFull;
    logic pop = 0;
    logic vld;
    logic [ DW - 1:0 ] data_out;
    logic empty;
  
    clocking cb @( posedge clk );
        default output #1;
        
        inout pop;
        output rst_n, push, data_in;
        input alFull, vld, data_out, empty, full;
    endclocking
    
    modport TB ( clocking cb );
endinterface
    
// =======================================================================

module tb;

parameter TBDW = 16;
parameter TBAW = 5;
parameter HEADROOM = 4;
  
logic clk;
  
// instantiate interface  
fifo_if #( .DW( TBDW ) ) theIF( clk );  
  
// instantiate the test  
main_prg #( .DW( TBDW ) ) u_main_prg( .i_f( theIF ) );  
  
// instantiate the DUT
fifo
#(
    .DW( TBDW ),
    .AW( TBAW ),
    .HEADROOM( HEADROOM )
)
u_fifo
(
    .clk( clk ),
    .rst_n( theIF.rst_n ),
    .push( theIF.push ),
    .data_in( theIF.data_in ),
    .alFull( theIF.alFull ),
    .pop( theIF.pop ),
    .vld( theIF.vld ),
    .data_out( theIF.data_out ),
    .full( theIF.full ),
    .empty( theIF.empty )
);
  
initial
begin
    $dumpfile( "dump.vcd" );
    $dumpvars( 0 );
end
  
initial
begin
    $timeformat( -9, 1, "ns", 8 );
    
    clk = 1'b0;
    forever #5 clk = ~clk;
end
  
endmodule  
    
// =======================================================================
  
program automatic main_prg
    #( parameter DW = 12 )
    ( fifo_if i_f );  

MyEnv#( .DW( DW ) ) env;
virtual fifo_if#(DW).TB sig_h = i_f.TB;
  
initial
begin
    env = new( sig_h );

    sig_h.cb.rst_n <= 1'b0;
    #50 sig_h.cb.rst_n <= 1'b1;
    repeat( 10 ) @( sig_h.cb );

    env.run();

    repeat( 2500 ) @( sig_h.cb );
end

endprogram  
