1..254  | ForEach-Object {
      if(!(Test-Connection 10.79.196.$_ -count 1 -Quiet)) {
	          Write-Output "IP Address Available 10.79.196.$_"
      }
    }