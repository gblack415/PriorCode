###############################################################################
# Description: Returns card number from SSO Prox-Card
# 06/24/22 glb created
# 07/18/22 glb updated wiegand cards
# 08/09/22 glb added 17 & 18 bit
# 03/13/25 glb added username for easier documentation
# http://www.proxmark.org/files/proxclone.com/iCLASS%20Wiegand%20Data%20Formats_26-37.pdf
###############################################################################
"PowerShell Version:$((Get-Host).Version)"
function High-Bit {

    param (
        $Card
    )
	$bits = 0
	while ( $Card -gt 0)
	{
		$Card = $Card -shr 1
		$bits = $bits + 1
	}
	
	return $bits
}

function Bit-Count {

    param (
        $Card
    )
	$bits = 0
	while ( $Card -gt 0)
	{
		
		if ($Card -band "0x1" )
		{
			$bits = $bits + 1
		}
		$Card = $Card -shr 1
	}
	
	return $bits
}

function O-Or-E {
	param (
	$TestNumber
	)
	$OE = "O"
	If([bool]!($TestNumber%2))
	{
		$OE = "E"
	}
	return $OE
}


function W26-E8-O16 {
	#iCLASS
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x1fff")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0xffff"
	$FacBits = Bit-Count -Card (($Card -shr 13) -band "0xfff")
	$FacParity = O-Or-E -TestNumber $FacBits
	$FacCode = ($Card -shr 17) -band "0xff"
	if (($FacParity -eq "E") -and ($CarParity -eq "O"))
	{
		"iCLASS - Facility Code: {0} {1}, Card Number: {2} {3}" -f $FacCode,$FacParity,$CardNumber,$CarParity
	}

}

function W34-E16-E16 {
	#H10306
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x1ffff")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0xffff"
	$FacBits = Bit-Count -Card (($Card -shr 17) -band "0x1ffff")
	$FacParity = O-Or-E -TestNumber $FacBits
	$FacCode = ($Card -shr 17) -band "0xffff"
	if (($FacParity -eq "E") -and ($CarParity -eq "E"))
	{
		"H10306 - Facility Code: {0} {1}, Card Number: {2} {3}" -f $FacCode,$FacParity,$CardNumber,$CarParity
	}

}
function W34-O16-O16 {
	
	#N10002
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x1ffff")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0xffff"
	$FacBits = Bit-Count -Card (($Card -shr 17) -band "0x1ffff")
	$FacParity = O-Or-E -TestNumber $FacBits
	$FacCode = ($Card -shr 17) -band "0xffff"
	if (($FacParity -eq "O") -and ($CarParity -eq "O"))
	{
		"N10002 - Facility Code: {0} {1}, Card Number: {2} {3}" -f $FacCode,$FacParity,$CardNumber,$CarParity
	}

}


function W35-E12-O20 {
	#IClass Corporate 1000
	#3 Parity bits
	#Test card 0x46461529B
    param (
        $Card
    )
	
	#$CarBits = Bit-Count -Card ($Card -band "0x1B6DB6DB6")
	$CarBits = Bit-Count -Card ($Card -band "0x1B6DB6DB7")
	$P1Parity = O-Or-E -TestNumber $CarBits #Odd
	$CardNumber = ($Card -shr 1) -band "0xfffff"
	#$FacBits = Bit-Count -Card (($Card -shr 1) -band "0x3B6DB6DB6")
	$P2Bits = Bit-Count -Card (($Card -shr 1) -band "0x1DB6DB6DB")
	$P2Parity = O-Or-E -TestNumber $P2Bits #E
	$P3Parity = O-Or-E -TestNumber (Bit-Count -Card ($Card -band "0x7FFFFFFFF"))
	$FacCode = ($Card -shr 21) -band "0xfff"
	#"IClass 1000 - Facility Code: {0}, Card Number: {1}, OEO: {2},{3},{4}" -f $FacCode,$CardNumber,$P1Parity,$P2Parity,$P3Parity
	if (($P1Parity -eq "O") -and ($P2Parity -eq "E") -and ($P3Parity -eq "O"))
	{
		"IClass 1000 - Facility Code: {0}, Card Number: {1}, OEO: {2},{3},{4}" -f $FacCode,$CardNumber,$P1Parity,$P2Parity,$P3Parity
	}
	
}

function W36-E8-O16 {
	#iCLASS 36
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x1ffff")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0xffff"
	$FacBits = Bit-Count -Card (($Card -shr 17) -band "0x1ff")
	$FacParity = O-Or-E -TestNumber $FacBits
	$FacCode = ($Card -shr 17) -band "0xff"
	if (($FacParity -eq "E") -and ($CarParity -eq "O"))
	{
		"iCLASS 36 - Facility Code: {0} {1}, Card Number: {2} {3}" -f $FacCode,$FacParity,$CardNumber,$CarParity
	}
}



function W37-E16-O19 {
	#H10304
	#FAC WRONG PARITY = 1000 0110 0100 0011 0011
	#FAC CODE = 1100 1000 1100
	#Calc Fac bits = 274995
	#0x10C8CDE8F1
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x7ffff")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0x7ffff"
	$FacBits = Bit-Count -Card (($Card -shr 18) -band "0x7FFFF")
	$FacParity = O-Or-E -TestNumber $FacBits
	$FacCode = ($Card -shr 20) -band "0xffff"
	#"fAC bits {0} {1}" -f $FacBits,($FacBits%2)
	if (($FacParity -eq "E") -and ($CarParity -eq "O"))
	{
		"H10304 - Facility Code: {0} {1}, Card Number: {2} {3}" -f $FacCode,$FacParity,$CardNumber,$CarParity
	}

}
function W37-EO36 {
	#H10302
	#0x1009B0A8C0
    param (
        $Card
    )
	$CarBits = Bit-Count -Card ($Card -band "0x7FFFF")
	$CarParity = O-Or-E -TestNumber $CarBits
	$CardNumber = ($Card -shr 1) -band "0x7FFFFFFFF"
	$FacBits = Bit-Count -Card (($Card -shr 18) -band "0x7FFFF")
	$FacParity = O-Or-E -TestNumber $FacBits
	#"Car bits {0} {1}" -f $CarBits,($Card -band "0xFFFFFFFFF")
	if (($FacParity -eq "E") -and ($CarParity -eq "O"))
	{
		"H10302 - Card Number: {0} EO:{1} {2}" -f $CardNumber,$FacParity,$CarParity
	}
}

if ($args.count -eq 1)
{
    $RawCard = $args[0]
}
elseif ($args.count -eq 2)
{
    $RawCard = $args[0]
	"Username: {0}" -f $args[1]
}
else
{
    $RawCard= Read-Host -Prompt "Card #"
    $RawCard = $RawCard.Trim()
}

if ($RawCard.Contains("0x") -eq $false) 
{
	$RawCard="0x" + $RawCard 
}
#$RawCard = "0000000240038F65"


"Raw Card Number: {0}" -f $RawCard
$HB = High-Bit -Card $RawCard
"Highest Used Bit: {0}" -f $HB
"20 Bit Card Number: {0}" -f (($RawCard -shr 1) -band "0xFFFFF")
"19 Bit Card Number: {0}" -f (($RawCard -shr 1) -band "0x7FFFF")
"18 Bit (Best choice): {0}" -f (($RawCard -shr 1) -band "0x3FFFF")
"17 Bit Card Number: {0}" -f (($RawCard -shr 1) -band "0x1FFFF")
"16 Bit Card Number: {0}" -f (($RawCard -shr 1) -band "0xFFFF")

if ($HB -le 26)
{
	W26-E8-O16  -Card $RawCard
}
if ($HB -le 34)
{
	W34-E16-E16 -Card $RawCard
	W34-O16-O16 -Card $RawCard
}
if ($HB -le 35)
{
	W35-E12-O20 -Card $RawCard
}
if ($HB -le 36)
{
	W36-E8-O16  -Card $RawCard
}
if ($HB -le 37)
{
	W37-E16-O19 -Card $RawCard
	W37-EO36 -Card $RawCard
}


Exit 0


