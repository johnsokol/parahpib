program gpib1;
uses crt,timer;

const dav  = 1;  { on control port }
      nrfd = 2;
      atn  = 4; { this line is inverted on output !}
      ndac = 8;

      srq  = 8;  { on status port }

      dat  = $3BC;
      stat = dat + 1;
      ctrl = dat + 2;

var c:char;
    s:string;
    t,a,b:integer;
    F:TEXT;
    err,srqf:boolean;
    dl:longint;


procedure commandit(c:char);
begin

{  write(c);
 }
 port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }

 port[dat] := ord(c) xor $ff; { SEND DATA INVERTED TO PORT }

 if port[ctrl] and (nrfd + ndac) = 0 then
   writeln('Error nrfd ndac are both asserted ');

 srqf := false;
 if port[stat] and srq = 0 then
     srqf := true;

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NDAC) or ( dl > 50000);
 err := err or (dl > 50000 );
                      { Till printer is ready to accept data }

 port[ctrl] := {atn +} dav;  { set dav low }

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NRFD ) or ( dl > 50000);
 err := err or (dl > 50000 );  { Till printer has accepted data }

 port[ctrl] := {atn}0;   { 0 in atn brings to hi state }

end;


function getst:byte;
begin

 port[dat] := $ff; { SEND 0 DATA TO PORT }

 if port[ctrl] and (nrfd + ndac) = 0 then
   writeln('Error nrfd ndac are both asserted ');
 port[ctrl] := NDAC + atn; { ready for data }

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and Dav = Dav) or (dl > 50000);
 err := err or (dl > 50000 );       { Till printer has data ready }
 getst := port[dat] xor $ff; { recieve DATA INVERTED from PORT }
 port[ctrl] := NRFD + atn; { Axcept data }

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and Dav = 0) or (dl > 50000);
  err := err or (dl > 50000 );
     { Till printer has accepted data }
 port[ctrl] := ndac + atn;
end;


function getstat(addr:integer):integer;
begin

 port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }
 port[dat] := 0;
 commandit(chr($18) ); { Serial pole enable }
 commandit(chr($40 + addr) ); { address 5 talk }
 port[ctrl] := ndac + atn;
 getstat :=  getst ;
 port[ctrl] := atn; { atn }
 port[ctrl] := 0; { atn }
 commandit('_'); { untalk }
 commandit(chr($19) ); { Serial pole disable }

end;

procedure dsrq;
begin
   b :=  getstat(4) ;
   writeln;
   writeln('SRQ pstat := ',b);
end;

procedure stt;
begin
 writeln;
 write(' Stat ');

 if port[ctrl] and dav = dav then
   write('DAV  ');

 if port[ctrl] and nrfd = nrfd then
   write('nrfd  ');

 if port[ctrl] and ndac = ndac then
   write('ndac  ');

 if port[ctrl] and atn = 0 then
   write('atn  ');

 writeln;
end;



function getit:byte;
begin

 port[dat] := $ff; { SEND 0 DATA TO PORT }

 if port[ctrl] and (nrfd + ndac) = 0 then
   writeln('Error nrfd ndac are both asserted ');
 srqf := false;
 if port[stat] and srq = 0 then
      srqf := true;
 port[ctrl] := NDAC + atn; { ready for data }

 dl := 0;
 repeat
 inc(dl);
 until (port[ctrl] and Dav = Dav) or ( dl > 50000);
  err := err or (dl > 50000 );
       { Till printer has data ready }

 getit := port[dat] xor $ff; { recieve DATA INVERTED from PORT }

 port[ctrl] := NRFD + atn; { Axcept data }

 dl := 0;
 repeat
 inc(dl);
 until (port[ctrl] and Dav = 0) or ( dl > 50000);
  err := err or (dl > 50000 );
   { Till printer has accepted data }

 port[ctrl] := ndac + atn;

end;


procedure printit(c:char);
begin

 port[dat] := ord(c) xor $ff; { SEND DATA INVERTED TO PORT }


 srqf := false;
 if port[stat] and srq = 0 then
     srqf := true
 else
   begin

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NDAC) or ( dl > 50000);
  err := err or (dl > 50000 );
                      { Till printer is ready to accept data }

 port[ctrl] := atn + dav;  { set dav low }

 dl := 0;
 repeat
  inc(dl);
 until (port[ctrl] and (nrfd + ndac) = NRFD) or ( dl > 50000);
  err := err or (dl > 50000 );
    { Till printer has accepted data }

 port[ctrl] := atn;   { 0 in atn brings to hi state }

 end;

end;


procedure talk(addr:integer);
begin

 port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }
 port[dat] := 0;

  commandit('?'); { unlisten }
  commandit('_'); { untalk }

  commandit(chr($40 + addr) ); { address 5 listen }

 port[ctrl] := atn ;  { 0 in atn brings to hi state }

end;



procedure listen(addr:integer);
begin

 port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }
 port[dat] := 0;

  commandit('_'); { untalk }
  commandit('?'); { unlisten }

  commandit(chr($20 + addr) ); { address 5 listen }

 port[ctrl] := atn ;  { 0 in atn brings to hi state }

end;


procedure init;
begin

 port[ctrl] := {atn}0 ;  { 0 in atn brings to hi state }
 port[dat] := 0;

  commandit(chr(14)); { address 5 listen }

 port[ctrl] := atn ;  { 0 in atn brings to hi state }

end;



begin
 srqf := false;
 err := false;
 clrscr;

t := 0;

 init;
 if err then
 begin
   err := false;
   writeln('init error');
 end;

 port[ctrl] := atn;
 port[dat] := 0;

 talk(4);
 if err then
 begin
   err := false;
   writeln('talk error');
 end;

 if srqf then dsrq;

 repeat

 repeat
 gotoxy(65,2);
 write(current_time,'   ');

   gotoxy(1,5);
   repeat
   a := getit;
   write(chr(a));
   until (a = 10) or err;
   nosound;
{   sound(400); }
   delay(1);
   nosound;

    if srqf then dsrq;
 until err;
 writeln('read Error');
 err := false;

 inc(t);

 gotoxy(65,4);
 write(current_time,'   ');
 gotoxy(1,7);
 writeln(' Num errors = ',t,'  ');

 init;
 if err then
 begin
   err := false;
   writeln('init error');
 end;

 port[ctrl] := atn;
 port[dat] := 0;

 talk(4);
 if err then
 begin
   err := false;
   writeln('talk error');
 end;

 if srqf then dsrq;

until t > 10;

end.



