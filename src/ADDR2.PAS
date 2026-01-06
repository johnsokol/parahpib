program addr2;
{*************************************************************************
 *
 *  1/92   Addr2  J Sokol.
 *
 *   Device address selection on GPIB buss interfaced on ibm Parrallel PORT
 *
 *
 *
 *************************************************************************
}

uses dos;

const dav  = 1;
      nrfd = 2;
      ndac = 8;

      atn  = 4;

      srq  = 8;
      tmo = 50000;


var c:char;
    s:string;
    a:integer;
    F:TEXT;
    err:boolean;
    regs : Registers;
     laddr,
     e,
     dat,
     stat,
     ctrl:word;



procedure printit(c:char);
var dl:word;
begin

{  write(c);
 }

 port[dat] := ord(c) xor $ff; { SEND DATA INVERTED TO PORT }

 if port[ctrl] and (nrfd + ndac) = nrfd + ndac then
   writeln('Error nrfd ndac are both asserted ');

 if port[stat] and srq = 0 then
   writeln('Printer srq asserted ');

 dl := 0;
 repeat
   inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NDAC) or (dl > tmo );
                      { Till printer is ready to accept data }
 if dl > tmo then err := true;

 port[ctrl] := {atn +} dav;  { set dav low }

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NRFD) or ( dl > tmo);  { Till printer has accepted data }

 if dl > tmo then err := true;

 port[ctrl] := {atn}0;   { 0 in atn brings to hi state }

end;





begin
   err := false;

  { DETECT printer driver in memory }
    regs.ah := 1;
    regs.dx := $FFFF;
    Intr($17,regs); { Call DOS }

    if $BACE <>  regs.dx then
    begin
      writeln('GPIB printer driver Not intalled');
      halt(1);
    end;


    writeln('Gpib driver detected on LPT ', regs.BX+1);
    writeln;

    dat := regs.CX;
    stat := dat + 1;
    ctrl := dat + 2;

    if paramcount <> 1 then err := true;
    val(paramstr(1),laddr,e);
    if e <> 0 then err := true;

    if laddr < 1 then err := true;
    if laddr > 31 then err := true;

    if err then
    begin
     Writeln('Usage: HDEV (device address)');
     writeln('      This program works with HPRN.COM to select a GPIB device on the buss');
     writeln('      Writteln By John L. Sokol 11/91 ');
     Halt(0);
    end;

    port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }
    port[dat] := 0;

    printit('?'); { unlisten }
    printit('_'); { untalk }

    printit(chr(laddr + $20) ); { address 5 listen }

    port[ctrl] := atn ;  { 0 in atn brings to hi state }

    if err then
      writeln('Buss timeout Error ')
    else
      writeln('DEVICE # ',laddr,' Enabled');
end.



