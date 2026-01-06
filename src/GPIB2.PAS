program gpib2;

const dav  = 1;
      nrfd = 2;
      ndac = 8;

      atn  = 4;

      srq  = 8;

      dat  = $378;
      stat = dat + 1;
      ctrl = dat + 2;

var c:char;
    s:string;
    a:integer;
    F:TEXT;


procedure printit(c:char);
begin

{  write(c);
 }
 port[dat] := ord(c) xor $ff; { SEND DATA INVERTED TO PORT }

 if port[ctrl] and (nrfd + ndac) = nrfd + ndac then
   writeln('Error nrfd ndac are both asserted ');

 if port[stat] and srq = 0 then
   writeln('Printer srq asserted ');

 repeat
 until port[ctrl] and (nrfd + ndac) = NDAC;
                      { Till printer is ready to accept data }

 port[ctrl] := atn + dav;  { set dav low }

 repeat
 until port[ctrl] and (nrfd + ndac) = NRFD;  { Till printer has accepted data }

 port[ctrl] := atn;   { 0 in atn brings to hi state }

end;




PROCEDURE printstr(s:string);
 VAR A:INTEGER;
begin
 for a := 1 to length(s) do
   printit(s[a]);

  printit(chr(10));
  printit(chr(13));

end;




begin


 port[ctrl] := atn;  { 0 in atn brings to hi state }
 port[dat] := 0;

 ASSIGN(F,PARAMSTR(1) );
 RESET(F);

 WHILE NOT EOF(F) DO
  BEGIN
    READ(F,C);
    PRINTIT(C);
  END;

    PRINTIT(CHR(12));


end.



