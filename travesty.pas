

PROGRAM travesty (input,output);            { Kenner/ O'Rourke, 5/9/84}

(*     This is based on Brian Hayes' article in Scientific           *)
(*     American, November 1983. It scans a text and generates        *)
(*     an n-order simulation of its letter combinations. For         *)
(*     order n, the relation of output to input is exactly:          *)
(*           "Any pattern n characters long in the output            *)
(*               has occurred somewhere in the input,                *)
(*                 and at about the same frequency."                 *)
(*     Input should be ready on disk. Pogram asks how many           *)
(*     characters of output you want. It next asks for the           *)
(*     "Order" -- i.e. how long a string of characters will be       *)
(*     cloned to output when found. You are asked for the            *)
(*     name of the input file, and offered a "Verse" option.         *)
(*     If you select this, and if the input has a "|" char-          *)
(*     acter at the end of each line, words that ends lines in       *)
(*     the original will terminate output lines. Otherwise,          *)
(*     output lines will average 50 characters in length.            *)

CONST 
	ArraySize = 3000;       {maximum number of text chars}
	MaxPat = 9;        {maximum Pattern length}

VAR
	BigArray : PACKED ARRAY [1..ArraySize] of CHAR;
	FreqArray, StartSkip : ARRAY[' '..'|'] of INTEGER;
	Pattern : PACKED ARRAY [1..MaxPat] of CHAR;
	SkipArray : ARRAY [1..ArraySize] of INTEGER;
	OutChars : INTEGER;    {number of characters to be output}
	PatLength : INTEGER;
	f : TEXT;
	CharCount : INTEGER; {characters so far output}
	Verse, NearEnd : BOOLEAN;
	NewChar : CHAR;
	TotalChars : INTEGER; {total chars input, + wraparound}
	Seed : INTEGER;

FUNCTION Random (VAR RandInt : INTEGER) : REAL;
BEGIN
	Random := RandInt / 1009;
	RandInt := (31 * RandInt + 11) MOD 1009
END;

PROCEDURE InParams;
	(* Obtains user's instructions *)
VAR
	InFile : STRING [12];
	Response : CHAR;
BEGIN
	WRITELN ('Enter a Seed (1..1000) for the randomizer');
	READLN (Seed);
	WRITELN ('Number of characters to be output?');
	READLN (OutChars);
	REPEAT
		WRITELN ('What order? <2-', MaxPat,'>');
		READLN (PatLength)
	UNTIL (PatLength IN [2..MaxPat]);
	PatLength := PatLength - 1;
	WRITELN ('Name of input file?');
	READLN (InFile);
	ASSIGN (f, InFile);
	RESET (f);
	WRITELN ('Prose or Verse? <p/v>');
	READLN (Response);
	IF (Response = 'V') OR (Response = 'v') THEN
		Verse := true
	ELSE Verse := false
END; {Procedure InParams}

PROCEDURE ClearFreq;
(*  FreqArray is indexed by 93 probable ASCII characters,            *)
(*  from " " to "|". Its elements are all set to zero.               *)
VAR
	ch : CHAR;
BEGIN
	FOR ch := ' ' TO '|' DO
		FreqArray[ch] := 0
END; {Procedure ClearFreq}

PROCEDURE NullArrays;
(* Fill BigArray and Pattern with nulls *)
VAR
	j : INTEGER;
BEGIN
	FOR j := 1 TO ArraySize DO
		BigArray[j] := CHR(0);
	FOR j := 1 TO MaxPat DO
		Pattern[j] := CHR(0)
END; {Procedure NullArrays}

PROCEDURE FillArray;
(*    Moves textfile from disk into BigArray, cleaning it            *)
(*    up and reducing any run of blanks to one blank.                *)
(*    Then copies to end of array a string of its opening            *)
(*    characters as long as the Pattern, in effect wrapping          *)
(*    the end to the beginning.                                      *)
VAR
	Blank : BOOLEAN;
	ch: CHAR;
	j: INTEGER;

	PROCEDURE Cleanup;
	(* Clears Carriage Returns, Linefeeds, and Tabs out of           *)
	(* input stream. All are changed to blanks.                      *)
	BEGIN
		IF ((ch = CHR(13)) 		{CR}
			OR (ch = CHR(10)) 	{LF}
			OR (ch = CHR(9)))	{TAB}
		THEN ch := ' '
	END;

BEGIN {Procedure FillArray}
	j := 1;
	Blank := false;
	WHILE (NOT EOF(f)) AND ( j <= (ArraySize - MaxPat)) DO
	BEGIN {While Not EOF}
		READ (f,ch);
		Cleanup;
		BigArray[j] := ch;            {Place character in BigArray}
		IF ch = '' THEN Blank := true;
		j := j + 1;
		WHILE (Blank AND (NOT EOF(f))
			AND (j <= (ArraySize - MaxPat))) DO
		BEGIN {While Blank}                {When a blank has just been}
			READ (f,ch);                      {printed, Blank is true,}
			Cleanup;                {so succeeding blanks are skipped,}
			IF ch <> '' THEN                      {thus stopping runs.}
			BEGIN {If}
				Blank := false;
				BigArray[j] := ch;         {To BigArray if not a Blank}
				j := j + 1
			END {If}
		END {While Blank}
	END; {While Not EOF}
	TotalChars := j - 1;
	IF BigArray[TotalChars] <> '' THEN
	BEGIN 	{If no Blank at end of text, append one}
		TotalChars := TotalChars + 1;
		BigArray[TotalChars] := ' '
	END;
	{Copy front of array to back to simulate wraparound.}
	FOR j := 1 TO PatLength DO
		BigArray[TotalChars + j] := BigArray[j];
	TotalChars := TotalChars + PatLength;
	WRITELN('Characters read, plus wraparound = ',TotalChars:4)
END; {Procedure FillArray}

PROCEDURE FirstPattern;
(* User selects "order" of operation, an integer, n, in the          *)
(* range 1 .. 9. The input text will henceforth be scanned           *)
(* in n-sized chunks. The first n-1 characters of the input          *)
(* file are placed in the "Pattern" Array. The Pattern is            *)
(* written at the head of output.                                    *)
VAR
	j : INTEGER;
BEGIN
	FOR j := 1 TO PatLength DO 	       {Put opening chars into Pattern}
		Pattern[j] := BigArray[j];
	CharCount := PatLength;
	NearEnd := false;
	IF Verse THEN WRITE (' ');   {Align first line}
	FOR j := 1 TO PatLength DO
		WRITE (Pattern[j])
	END; {Procedure FirstPattern}

PROCEDURE InitSkip;
(* 	The i-th entry of SkipArray contains the smallest index          *)
(* 	j > i such that BigArray[j] = BigArray[i]. Thus SkipArray        *)
(* 	links together all identical characters in BigArray.             *)
(* 	StartSkip contains the index of the first occurrence of          *)
(* 	each character. These two arrays are used to skip the            *)
(* 	matching routine through the text, stopping only at              *)
(* 	locations whose character matches the first character            *)
(* 	in Pattern.                                                      *)
VAR
	ch : CHAR;
	j : INTEGER;
BEGIN
	FOR ch := ' ' TO '|' DO
		StartSkip[ch] := TotalChars + 1;
	FOR j := TotalChars DOWNTO 1 DO
	BEGIN
		ch := BigArray[j];
		SkipArray[j] := StartSkip[ch];
		StartSkip[ch] := j
	END
END; {Procedure InitSkip}

PROCEDURE Match;
(* 	Checks BigArray for strings that match Pattern; for each         *)
(* 	match found, notes following character and increments its        *)
(* 	count in FreqArray. Position for first trial comes from          *)
(* 	StartSkip; thereafter positions are taken from SkipArray.        *)
(* 	Thus no sequence is checked unless its first character is        *)
(* 	already known to match first character of Pattern.               *)
VAR
	i : INTEGER;   {one location before start of the match in BigArray}
	j : INTEGER; {index into Pattern}
	Found : BOOLEAN;    {true if there is a match from i+1 to i+j - 1 }
	ch1 : CHAR;     {the first character in Pattern; used for skipping}
	NxtCh : CHAR;
BEGIN {Procedure Match}
	ch1 := Pattern[1];
	i := StartSkip[ch1] - 1;       {is is 1 to left of the Match start}
	WHILE (i <= TotalChars - PatLength - 1) DO
	BEGIN {While}
		j := 1;
		Found := true;
		WHILE (Found AND (j <= PatLength)) DO
			IF BigArray[i+j] <> Pattern[j]
				THEN Found := false   {Go thru Pattern til Match fails}
				ELSE j := j + 1;
			IF Found THEN
			BEGIN 		       {Note next char and increment FreqArray}
				NxtCh := BigArray[i + PatLength + 1];
				FreqArray[NxtCh] := FreqArray[NxtCh] + 1
			END;
			i := SkipArray[i + 1] - 1  {Skip to next matching position}
		END {While}
	END; {Procedure Match}

PROCEDURE WriteCharacter;
(* 	The next character is written. It is chosen at Random            *)
(* 	from characters accumulated in FreqArray during last             *)
(* 	scan of input. Output lines will average 50 character            *)
(* 	in length. If "Verse" option has been selected, a new            *)
(* 	line will commence after any word that ends with "|" in          *)
(* 	input file. Thereafter lines will be indented until              *)
(* 	the 50-character average has been made up.                       *)
VAR
	Counter, Total, Toss : INTEGER;
	ch : CHAR;
BEGIN
	Total := 0;
	FOR ch := ' ' TO '|' DO
	Total := Total + FreqArray[ch]; {Sum counts in FreqArray}
	Toss := TRUNC (Total * Random(Seed)) + 1;
	Counter := 31;
	REPEAT
		Counter := Counter + 1; 	                {We begin with ' '}
		Toss := Toss - FreqArray[CHR(Counter)]
		until Toss <= 0;                               {Char chosen by}
	NewChar := CHR(Counter);                  {successive subtractions}
	IF NewChar <> '|' THEN
		WRITE (NewChar);
	CharCount := CharCount + 1;
	IF CharCount MOD 50 = 0 THEN NearEnd := true;
	IF ((Verse) AND (NewChar = '|')) THEN WRITELN;
	IF ((NearEnd) AND (NewChar = ' ')) THEN
	BEGIN {If NearEnd}
		WRITELN;
		IF Verse THEN WRITE ('     ');
		NearEnd := false
	END {If NearEnd}
END; {Procedure Write Character}

PROCEDURE NewPattern;
(* 	This removes the first character of the Pattern and              *)
(* 	appends the character just printed. FreqArray is                 *)
(* 	zeroed in preparation for a new scan.                            *)
VAR
	j : INTEGER;
BEGIN
	FOR j := 1 to PatLength - 1 DO
		Pattern[j] := Pattern[j + 1];         {Move all chars leftward}
	Pattern[PatLength] := NewChar;                     {Append NewChar}
	ClearFreq
END; {Procedure NewPattern}

BEGIN {Main Program}
	ClearFreq;
	NullArrays;
	InParams;
	FillArray;
	FirstPattern;
	InitSkip;
	REPEAT
		Match;
		WriteCharacter;
		NewPattern
	UNTIL CharCount >= OutChars;
END. {Main Program}
