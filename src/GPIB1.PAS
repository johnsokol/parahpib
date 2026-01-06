program gpib1;

uses dos,crt;

const dav  = 1;
      nrfd = 2;
      ndac = 8;

      atn  = 4;

      srq  = 8;

      dat  = $378;
      stat = dat + 1;
      ctrl = dat + 2;

var c:char;



procedure printit(c:char);
begin

   write(c);

 if port[ctrl] and (nrfd + ndac) = nrfd + ndac then
   writeln('Error nrfd ndac are both asserted ');

 if port[stat] and srq = 0 then
   writeln('Printer srq asserted ');


 port[dat] := ord(c) xor $ff;

 repeat
 until port[ctrl] and nrfd = 0;  { Till printer is ready to accept data }
 delay(10);


 port[ctrl] := atn + dav;  { set dav low }


 repeat
 until port[ctrl] and ndac <> 0;  { Till printer has accepted data }

 delay(10);

 port[ctrl] := atn;   { 0 in atn brings to hi state }

end;


begin


clrscr;

 port[ctrl] := atn;  { 0 in atn brings to hi state }
 port[dat] := 0;


repeat
 c := readkey;
 if c <> chr(27) then
  begin
    if c = chr(13) then
     printit(chr(10));

     printit(c);
   
  end;

until c = chr(27);


end.



