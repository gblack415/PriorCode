###############################################################################
# Description: sends test efaxes thru RightFax via fcl file on share
# 07/20/26 glb created 
# FCL FILE MUST BE UTF-8 ENCODING
###############################################################################
ipconfig /flushdns
"PowerShell Version: $((Get-Host).Version)"
"==============================================================================="
'Start: {0}' -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$FL=@('9999999999')
$unc="\\XXXXX\inbox$\"
$name = "Garth Black"
$sam = "garbla"
$spiral = "D:\GarBla\Attachments\AAA-Fax-Test-Sheet-PDF17-Spiral.pdf"
$initials = "GLB"
$ComputerName = "w300060"
$li = "################################################################################
Sample Text(Lorem Ipsum)
################################################################################
Lorem ipsum dolor sit amet. Non porro voluptatum vel galisum nisi 
est voluptatibus illum qui laboriosam vero rem consectetur nostrum 
aut consequuntur rerum! Est possimus perferendis et doloribus 
beatae eum ratione excepturi rem accusamus velit et dolorem 
maiores est impedit quod.

Qui mollitia officiis est earum similique et Quis asperiores et rerum 
maiores ex mollitia soluta ea officiis similique. Vel consequatur placeat 
sed ipsam vero cum mollitia tempora. Nam consequatur suscipit qui 
consectetur sint aut repellendus quasi et maiores veniam in dicta eius 
nam repellendus temporibus a repellat consequatur!

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod 
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. 
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat
nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui"

If (Test-Connection $ComputerName -Count 1 -ErrorAction 0 -Quiet) 
{ 
    Write-Host "$ComputerName is Pingable" -ForegroundColor Green 
    foreach($efn in $FL)
    {
    $fn = $unc + "GLB" + -join ((65..90) + (48..57) | Get-Random -Count 29 | % {[char]$_}) + ".fcl"
    $af1 = $unc + "GLB" + -join ((65..90) + (48..57) | Get-Random -Count 29 | % {[char]$_}) + ".pdf"
    $rn = Get-Random -Maximum 999
    "Fax#: {0}" -f $efn
    "{{begin}}" | Out-File $fn -Append -Encoding Utf8
    "{{fax $efn}}" | Out-File $fn -Append -Encoding Utf8
    "{{contact Daily Test - $name}}" | Out-File $fn -Append -Encoding Utf8
    "{{winsecid $sam}}" | Out-File $fn -Append -Encoding Utf8
    "{{quality fine}}" | Out-File $fn -Append -Encoding Utf8
    "{{owner $name (Owner)}}" | Out-File $fn -Append -Encoding Utf8
    "{{covertext}}This is a test efax. Random Number: $rn {{ENDCOVERTEXT}}" | Out-File $fn -Append -Encoding Utf8
	    if (Test-Path $spiral)
	    {
            Copy-Item -Path $spiral -Destination $af1
            if (Test-Path $af1)
	        {
            "{{attach $af1 delete}}" | Out-File $fn -Append -Encoding Utf8
            }
        }
    "{{cover RFDEFAULT}}" | Out-File $fn -Append -Encoding Utf8
    "Fax #: $efn" | Out-File $fn -Append -Encoding Utf8
    "Date: $(get-date)" | Out-File $fn -Append -Encoding Utf8
    "Random Number: $rn" | Out-File $fn -Append -Encoding Utf8
    $li | Out-File $fn -Append -Encoding Utf8
    "{{end}}" | Out-File $fn -Append -Encoding Utf8
    }
 }
 Else 
{ 
    Write-Host "$ComputerName is DOWN, bye" -ForegroundColor Red 
    Start-Sleep -s 5
    Exit 1
}
'End: {0}' -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
