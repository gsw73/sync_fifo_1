class DataPkt #( parameter DW = 7 );

    rand bit [ DW - 1:0 ] fifo_data;

endclass

// =======================================================================

class pshAgnt #( parameter DW = 3 );

    mailbox mbxPsh;
    mailbox mbxSB;
    DataPkt#(DW) d;

    function new( mailbox mbxPsh, mailbox mbxSB );
        this.mbxPsh = mbxPsh;
        this.mbxSB = mbxSB;
    endfunction

    task run();
      repeat( 500 )
      begin
          d = new();
          d.randomize();
          mbxPsh.put( d );
          mbxSB.put( d );
      end
    endtask

endclass

// =======================================================================

class pshXactor #( parameter DW = 4 );

    mailbox mbxPsh;

    virtual fifo_if#(DW).TB sig_h;

    function new( mailbox mbxPsh, virtual fifo_if#(DW).TB s );
        this.mbxPsh = mbxPsh;
        sig_h = s;
    endfunction

    task run();
        DataPkt#(DW) data;
        uint32_t pshCnt;
        
        forever
        begin
            mbxPsh.get( data );

            repeat( $urandom & 3 ) @( sig_h.cb );
            wait( ~sig_h.cb.alFull ) ;
            sig_h.cb.push <= 1;
            sig_h.cb.data_in <= data.fifo_data;

            @( sig_h.cb )
            sig_h.cb.push <= 0;
            sig_h.cb.data_in <= 0;
            pshCnt++;
        end
    endtask;

endclass

// =======================================================================

class popXactor #( parameter DW = 33 );
  
    mailbox mbxPop;
  
    virtual fifo_if#(DW).TB sig_h;

    function new( mailbox m, virtual fifo_if#(DW).TB s );
        this.mbxPop = m;
        sig_h = s;
    endfunction

    task run();
      DataPkt#(DW) data;
      
      fork
          forever
          begin
              repeat( $urandom & 3 ) @( sig_h.cb );
              sig_h.cb.pop <= 1;
              repeat( $urandom & 3 ) @( sig_h.cb );
              sig_h.cb.pop <= 0;
          end
      join_none
          
      forever
      begin
          wait( sig_h.cb.pop && sig_h.cb.vld );
          data = new;
          data.fifo_data = sig_h.cb.data_out;
          mbxPop.put( data );
          @( sig_h.cb );
      end
    endtask
endclass

// =======================================================================

class popAgnt #( parameter DW = 4 );
  
    mailbox mbxPop;
    mailbox mbxSB;
  
    virtual fifo_if#(DW).TB sig_h;
    
    function new( mailbox m_pop, mailbox m_sb, virtual fifo_if#(DW).TB s );
        mbxPop = m_pop;
        mbxSB = m_sb;
        sig_h = s;
    endfunction
    
    task run();
        DataPkt#(DW) d_out;
        DataPkt#(DW) d_sb;
        uint32_t cnt_total;
        pf_e chk;
        
        forever
        begin
            mbxPop.get( d_out );
            mbxSB.get( d_sb );
            
            chk = pf_e'( d_out.fifo_data == d_sb.fifo_data );
            cnt_total++;
            
            $display( "@%t d_out = %h d_sb = %h chk = %0s cnt = %0d", $realtime, d_out.fifo_data, d_sb.fifo_data, chk.name, cnt_total );
            
            if ( chk == FAIL )
            begin
                $display( "@%t ERROR DETECTED; exiting", $realtime );
                repeat( 100 ) @( sig_h.cb );
                $finish;
            end
        end
    endtask
  
endclass

// =======================================================================

class MyEnv #( parameter DW = 41 );

    pshXactor#(DW) pshX;
    popXactor#(DW) popX;
    mailbox mbxPsh;
    mailbox mbxPop;
    mailbox mbxSB;
    pshAgnt#(DW) pshA;
    popAgnt#(DW) popA;

    virtual fifo_if#(DW).TB sig_h;

    function new( virtual fifo_if#(DW).TB s );
        mbxPsh = new();
        mbxPop = new();
        mbxSB = new();

        sig_h = s;

        pshX = new( mbxPsh, s );
        pshA = new( mbxPsh, mbxSB );
        popX = new( mbxPop, s );  
        popA = new( mbxPop, mbxSB, s );
    endfunction

    task run();
        fork 
            pshX.run();
            pshA.run();
            popX.run();
            popA.run();
        join_none
    endtask

endclass
        
