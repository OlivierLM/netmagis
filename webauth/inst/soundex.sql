\encoding latin9
CREATE FUNCTION soundex (TEXT) RETURNS TEXT AS '
	array set soundexFrenchCode {
	    a 0 b 1 c 2 d 3 e 0 f 9 g 7 h 0 i 0 j 7 k 2 l 4 m 5
	    n 5 o 0 p 1 q 2 r 6 s 8 t 3 u 0 v 9 w 9 x 8 y 0 z 8
	}
	set accentedFrenchMap {
	    � e  � e  � e  � e   � E  � E  � E  � E
	     � a  � a  � a        � A  � A  � A
	     � i  � i             � I  � I
	     � o  � o             � O  � O
	     � u  � u  � u        � U  � U  � U
	     � ss                 � SS
	}
	set key ""

	# Map accented characters
	set TempIn [string map $accentedFrenchMap $1]

	# Only use alphabetic characters, so strip out all others
	# also, soundex index uses only lower case chars, so force to lower

	regsub -all {[^a-z]} [string tolower $TempIn] {} TempIn
	if {[string length $TempIn] == 0} {
	    return Z000
	}
	set last [string index $TempIn 0]
	set key  [string toupper $last]
	set last $soundexFrenchCode($last)

	# Scan rest of string, stop at end of string or when the key is
	# full

	set count    1
	set MaxIndex [string length $TempIn]

	for {set index 1} {(($count < 4) && ($index < $MaxIndex))} {incr index } {
	    set chcode $soundexFrenchCode([string index $TempIn $index])
	    # Fold together adjacent letters sharing the same code
	    if {![string equal $last $chcode]} {
		set last $chcode
		# Ignore code==0 letters except as separators
		if {$last != 0} then {
		    set key $key$last
		    incr count
		}
	    }
	}
	return [string range ${key}0000 0 3]
    ' LANGUAGE 'pltcl' WITH (isStrict) ;
