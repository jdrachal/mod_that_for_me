$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Path $scriptPath -Parent
$bepInEx = Join-Path -Path $scriptDirectory -ChildPath "BepInEx"

$bepInExURL = "https://thunderstore.io/package/download/BepInEx/BepInExPack/5.4.2100/"
$lcApiURL = "https://thunderstore.io/package/download/2018/LC_API/3.1.0/"

# Path to the text file containing URLs
$urlsFile = ".\mod_urls.txt"

# It needs update if BepInEx will contain any other items outside of BepInEx directory
$bepInExItems = @("doorstop_config.ini", "winhttp.dll")

function ApplyModsFromFile {
	# Read URLs from the file
	$urls = Get-Content $urlsFile

	# Loop through each URL and download the files
	foreach ($url in $urls) {
		$filename = Split-Path -Leaf $url  # Extract filename from URL
		$outputFile = "tmp.zip" #Join-Path -Path . -ChildPath $filename  # Set output file path
		
		# Download the file
		Invoke-WebRequest -Uri $url -OutFile $outputFile
		
		# Unzip the downloaded ZIP file
		Expand-Archive -Path $outputFile -DestinationPath . -Force
		
		Remove-Item -Path $outputFile -Force

		Write-Host "Downloaded: $url"
	}


	$pluginsDirectory = Join-Path -Path $PSScriptRoot -ChildPath "plugins"

	if (Test-Path -Path $pluginsDirectory -PathType Container) {
		# Move the "plugins" directory to the specified destination
		Copy-Item -Path $pluginsDirectory -Destination $bepInEx -Recurse -Force

		Write-Host "The 'plugins' directory has been moved to: $bepInEx"
		
		Remove-Item -Path $pluginsDirectory -Recurse -Force
	}
}

function RemoveAllBepInExItems {
	if (Test-Path -Path $bepInEx -PathType Container) {
		Remove-Item -Path $bepInEx -Recurse -Force
	}
    foreach ($item in $bepInExItems) {
		$itemToRemove = Join-Path -Path $scriptDirectory -ChildPath $item
		if (Test-Path -Path $itemToRemove -PathType Container) {
			Remove-Item -Path $itemToRemove -Recurse -Force
		}
	}
}

function ExtractLcApi {
	$lcApiZip = "lcApi.zip"
	$lcApiDir = Join-Path -Path $scriptDirectory -ChildPath "lcApi"

	# Download the ZIP file
	Invoke-WebRequest -Uri $lcApiURL -OutFile $lcApiZip

	# Create temporary directory
	if (-not (Test-Path -Path $lcApiDir -PathType Container)) {
		New-Item -ItemType Directory -Path $lcApiDir | Out-Null
	}

	# Unzip lcApi.zip into a temporary directory
	Expand-Archive -Path $lcApiZip -DestinationPath $lcApiDir -Force
	
	# Copy from temporary lcAPI\BepInEx\plugins dir to final BepInEx\plugins\2018-LC_API dir
	# as version 3.1.0 needs direct copy with 2018-LC_API dir creation in BepInEx\plugins
	$lcApiBepInExPluginsDir = Join-Path -Path $lcApiDir -ChildPath "BepInEx\plugins"
	$lcApiBepInExPluginsDestDir = Join-Path -Path $scriptDirectory -ChildPath "BepInEx\plugins\2018-LC_API"
	robocopy $lcApiBepInExPluginsDir $lcApiBepInExPluginsDestDir /MOVE /S

	## Cleanup
	# Remove downloaded ZIP file
	Remove-Item -Path $lcApiZip -Force

	# Remove the temporary directory
	Remove-Item -Path $lcApiDir -Force -Recurse
}

function ExtractBepInExPack {
	$bepInExZip = "bepInEx.zip"
	$bepInExDir = Join-Path -Path $scriptDirectory -ChildPath "BepInExPack"

	# Download the ZIP file
	Invoke-WebRequest -Uri $bepInExURL -OutFile $bepInExZip

	# Unzip bepInEx.zip into a temporary directory
	Expand-Archive -Path $bepInExZip -DestinationPath . -Force

	# Get the content of the temporary directory
	$tempDirContent = Get-ChildItem -Path $bepInExDir -Force

	# Move the content of the temporary directory to the current directory
	foreach ($item in $tempDirContent) {
		Move-Item -Path $item.FullName -Destination . -Force
	}
	
	## Cleanup
	# Remove the temporary directory
	Remove-Item -Path $bepInExDir -Force -Recurse

	# Remove the downloaded ZIP file
	Remove-Item -Path $bepInExZip -Force
	
}

# Parse arguments
foreach ($arg in $args) {
    switch ($arg) {
        '-Force' {
            RemoveAllBepInExItems
            break
        }
        '-Clean' {
            RemoveAllBepInExItems
            exit 0
        }
        default {
            Write-Host "Invalid argument: $arg"
            exit 1
        }
    }
}

# Finish script if $bepInEx exists
if (Test-Path -Path $bepInEx -PathType Container) {
	Write-Host "BepInEx mod directory already exists"
    exit 0
}

# Extract BepInExPack
ExtractBepInExPack

# Extract LcAPI
ExtractLcApi  

# Apply mods from file $urlsFile
ApplyModsFromFile