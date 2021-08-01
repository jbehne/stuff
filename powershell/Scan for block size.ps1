﻿$blocksize = @()
$srv = @(
"C1APP017",
"C1APP267",
"C1APP270",
"C1APP309",
"C1APP388",
"C1APP390",
"C1APP399",
"C1APP666",
"C1APP711",
"C1DBD004",
"C1DBD007",
"C1DBD008",
"C1DBD010",
"C1DBD016",
"C1DBD017",
"C1DBD018",
"C1DBD019",
"C1DBD020",
"C1DBD021",
"C1DBD022",
"C1DBD023",
"C1DBD024",
"C1DBD025",
"C1DBD028",
"C1DBD029",
"C1DBD030",
"C1DBD031",
"C1DBD033",
"C1DBD034",
"C1DBD035",
"C1DBD036",
"C1DBD037",
"C1DBD038",
"C1DBD039",
"C1DBD040",
"C1DBD041",
"C1DBD042",
"C1DBD043",
"C1DBD044",
"C1DBD045",
"C1DBD046",
"C1DBD047",
"C1DBD048",
"C1DBD049",
"C1DBD050",
"C1DBD051",
"C1DBD052",
"C1DBD053",
"C1DBD054",
"C1DBD055",
"C1DBD056",
"C1DBD057",
"C1DBD058",
"C1DBD059",
"C1DBD061",
"C1DBD062",
"C1DBD063",
"C1DBD070",
"C1DBD071",
"C1DBD088",
"C1DBD089",
"C1DBD102",
"C1DBD105",
"C1DBD106",
"C1DBD120",
"C1DBD121",
"C1DBD122",
"C1DBD123",
"C1DBD124",
"C1DBD136",
"C1DBD191",
"C1DBD202",
"C1DBD212",
"C1DBD214",
"C1DBD215",
"C1DBD216",
"C1DBD222",
"C1DBD302",
"C1DBD305",
"C1DBD307",
"C1DBD309",
"C1DBD403",
"C1DBD404",
"C1DBD407",
"C1DBD408",
"C1DBD409",
"C1DBD411",
"C1DBD412",
"C1DBD416",
"C1DBD420",
"C1DBD421",
"C1DBD422",
"C1DBD423",
"C1DBD424",
"C1DBD430",
"C1DBD500",
"C1DBD502",
"C1DBD503",
"C1DBD504",
"C1DBD505",
"C1DBD507",
"C1DBD508",
"C1DBD509",
"C1DBD510",
"C1DBD511",
"C1DBD512",
"C1DBD513",
"C1DBD514",
"C1DBD516",
"C1DBD517",
"C1DBD518",
"C1DBD519",
"C1DBD520",
"C1DBD521",
"C1DBD522",
"C1DBD523",
"C1DBD525",
"C1DBD526",
"C1DBD527",
"C1DBD528",
"C1DBD529",
"C1DBD530",
"C1DBD531",
"C1DBD532",
"C1DBD533",
"C1DBD534",
"C1DBD535",
"C1DBD582",
"C1DBD583",
"C1DBD584",
"C1DBD585",
"C1DBD587",
"C1DBD588",
"C1DBD593",
"C1DBD700",
"C1DBD701",
"C1DBD702",
"C1DBD703",
"C1DBD705",
"C1DBD706",
"C1DBD707",
"C1DBD708",
"C1DBD709",
"C1DBD710",
"C1DBD711",
"C1DBD712",
"C1DBD713",
"C1DBD714",
"C1DBD715",
"C1DBD716",
"C1DBD717",
"C1DBD718",
"C1DBD719",
"C1DBD720",
"C1DBD721",
"C1DBD722",
"C1DBD723",
"C1DBD724",
"C1DBD780",
"C1DBD781",
"C1DBD782",
"C1DBD784",
"C1DBD785",
"C1IPT040",
"C1IPT041",
"C1IPT733",
"C1IPT841",
"C1IPT842",
"C1IPT843",
"C1UTL019",
"C2APP003",
"C6APP767",
"C6APP787",
"C6DBD001",
"C6DBD002",
"C6DBD036",
"C6DBD413",
"C6DBD430",
"C6DBD431",
"C6DBD435",
"C6DBD500",
"C6DBD583",
"C6DBD584",
"C6DBD700",
"C6DBD702",
"C6DBD703",
"C6DBD704",
"C6DBD791",
"C6IPT040",
"C6IPT042",
"C6IPT050",
"C7DBD020",
"C7DBD021",
"C7DBD430",
"MMDBD016",
"MMDBD103",
"MMDBD416",
"SBBMILT1")


foreach ($s in $srv)
{
    $blocksize += Get-CimInstance -ClassName Win32_Volume -ComputerName $s -ErrorAction SilentlyContinue | Select-Object {$s}, Label, BlockSize
}