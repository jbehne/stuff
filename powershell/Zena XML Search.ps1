[xml]$xml = Get-Content C:\Users\id67065\Documents\rexx\zena.xml


foreach ($x in $xml.PACKAGE.DEFINITIONS.DEFINITION)
{
    if ($x.OuterXML -like "*CFAR-EMAIL-IF-BLOCKING*")
    {
        $x.NAME
    }
}
