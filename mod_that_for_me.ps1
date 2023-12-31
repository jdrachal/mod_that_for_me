$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Path $scriptPath -Parent
$tempRootDir = Join-Path -Path $env:TEMP -ChildPath "lethalCompanyMods"

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Warning!`nTo change ExecutionPolicy Run Windows Powershell as Administrator and call this script from console"
} else {
    Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
}

$bepInExURL = "https://thunderstore.io/package/download/BepInEx/BepInExPack/5.4.2100/"
$lcApiURL = "https://thunderstore.io/package/download/2018/LC_API/3.1.0/"

# Path to the text file containing URLs
$urlsFile = Join-Path -Path $scriptDirectory -ChildPath "mod_urls.txt"

# It needs update if BepInEx will contain any other items outside of BepInEx directory
$bepInExItems = @("doorstop_config.ini", "winhttp.dll")

# Define the name of the game you want to find
$gameName = "Lethal Company"

# Function to retrieve Steam library folders
function Get-SteamLibraryFolders {
    $steamFolder = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam').SteamPath
    $libraryFolders = @($steamFolder)

    $libraryFoldersFile = Join-Path -Path $steamFolder -ChildPath 'steamapps\libraryfolders.vdf'

    if (Test-Path $libraryFoldersFile) {
        $libraryFoldersContent = Get-Content -Path $libraryFoldersFile -Raw

        $matches = [regex]::Matches($libraryFoldersContent, '"path"\s*"(.*?)"')
        foreach ($match in $matches) {
            $libraryFolder = $match.Groups[1].Value
            $libraryFolders += $libraryFolder
        }
    }

    return $libraryFolders
}

# Function to find the game folder in Steam app manifest files
function Find-SteamgameDirectory($gameName, $libraryFolders) {
    $gameFound = $false
	$gameDirectory = ""

    foreach ($folder in $libraryFolders) {
        $steamAppsFolder = Join-Path -Path $folder -ChildPath 'steamapps'
		$gameDirectory = Join-Path -Path $steamAppsFolder -ChildPath "common\$gameName"

		if (Test-Path $gameDirectory) {
			#Write-Output "$gameName found at: $gameDirectory"
			$gameFound = $true
		}
    }

    if (-not $gameFound) {
        throw [System.IO.FileNotFoundException] "$file not found."
    }
	return $gameDirectory
}

# Find the specified game in the Steam installation paths
$steamLibraryFolders = Get-SteamLibraryFolders
$gameDirectory = Find-SteamgameDirectory -gameName $gameName -libraryFolders $steamLibraryFolders
$bepInEx = Join-Path -Path $gameDirectory -ChildPath "BepInEx"

function ApplyModsFromFile {
	# Read URLs from the file
	$urls = Get-Content $urlsFile

	# Loop through each URL and download the files
	foreach ($url in $urls) {
		$filename = Split-Path -Leaf $url  # Extract filename from URL
		$outputFile = Join-Path -Path $tempRootDir -ChildPath "tmp.zip" #Join-Path -Path . -ChildPath $filename  # Set output file path

		# Download the file
		Invoke-WebRequest -Uri $url -OutFile $outputFile

		# Unzip the downloaded ZIP file
		Expand-Archive -Path $outputFile -DestinationPath $tempRootDir -Force

		Remove-Item -Path $outputFile -Force

		Write-Host "Downloaded: $url"
	}


	$tempBepInExDirectory = Join-Path -Path $tempRootDir -ChildPath "BepInEx"
	$tempPluginsDirectory = Join-Path -Path $tempRootDir -ChildPath "plugins"
	$bepInExPluginsDirectory = Join-Path -Path $bepInEx -ChildPath "plugins"

	Copy-Item -Path $tempBepInExDirectory -Destination $gameDirectory -Recurse -Force
	Copy-Item -Path $tempRootDir\*.dll -Destination $bepInExPluginsDirectory

	if (Test-Path -Path $tempPluginsDirectory -PathType Container) {
		Copy-Item -Path $tempPluginsDirectory -Destination $bepInEx -Recurse -Force
	}
}

function RemoveAllBepInExItems {
	if (Test-Path -Path $bepInEx -PathType Container) {
		Remove-Item -Path $bepInEx -Recurse -Force
		Write-Host "`nRemoved all mods from $bepInEx"
	} else {
		Write-Host "Nothing to be removed"
	}
    foreach ($item in $bepInExItems) {
		$itemToRemove = Join-Path -Path $gameDirectory -ChildPath $item

		if (Test-Path -Path $itemToRemove) {
			Remove-Item -Path $itemToRemove -Recurse -Force
			Write-Host "Removed related mods file: $itemToRemove"
		}
	}
}

function ExtractLcApi {
	$lcApiZip = Join-Path -Path $tempRootDir -ChildPath "lcApi.zip"
	$lcApiDir = Join-Path -Path $tempRootDir -ChildPath "lcApi"

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
	$lcApiBepInExPluginsDestDir = Join-Path -Path $gameDirectory -ChildPath "BepInEx\plugins\2018-LC_API"
	robocopy $lcApiBepInExPluginsDir $lcApiBepInExPluginsDestDir /MOVE /S
	if (Test-Path $lcApiZip) {
		Write-Host "Downloaded: $lcApiURL"
	}
}

function ExtractBepInExPack {
	$bepInExZip = Join-Path -Path $tempRootDir -ChildPath "bepInEx.zip"
	$bepInExDir = Join-Path -Path $tempRootDir -ChildPath "BepInExPack"

	# Download the ZIP file
	Invoke-WebRequest -Uri $bepInExURL -OutFile $bepInExZip

	# Unzip bepInEx.zip into a temporary directory
	Expand-Archive -Path $bepInExZip -DestinationPath $tempRootDir -Force

	# Get the content of the temporary directory
	$tempRootDirContent = Get-ChildItem -Path $bepInExDir -Force

	# Move the content of the temporary directory to the current directory
	foreach ($item in $tempRootDirContent) {
		Move-Item -Path $item.FullName -Destination $gameDirectory -Force
	}
	if (Test-Path $bepInExZip) {
		Write-Host "Downloaded: $bepInExURL"
	}
}

function PrintModList {
	$urls = Get-Content $urlsFile
	Write-Host "`nMod list from $urlsFile"
	# Loop through each URL and download the files
	$modList = foreach ($url in $urls) {
		$parts = $url -split '/'
		$modName = $parts[-3]
		$modVer = $parts[-2]

		[PSCustomObject]@{
			Name = $modName
			Version = $modVer
		}
	}
	$modList | Format-Table -AutoSize
}

function Prompt-LoggingConsole {
    $response = Read-Host "`nDo you want to show logging console while playing? (Y/N)"

	# Define the path to your config file
	$configFilePath = Join-Path -Path $bepInEx -ChildPath "config\BepInEx.cfg"
	$configContent = Get-Content -Path $configFilePath -Raw
	$sectionName = "Logging.Console"
	$pattern = "(?ms)(\[$sectionName\].*?^Enabled\s*=\s*)\w+"


    if ($response -eq 'Y' -or $response -eq 'y') {
		# Find the section and modify the Enabled setting
		$newConfigContent = $configContent -replace $pattern, "`$1true"
		Write-Host "Config $configFilePath changed"
		Write-Host "Section $sectionName, key: Enabled = true"
    } else {
        $newConfigContent = $configContent -replace $pattern, "`$1false"
		Write-Host "Config $configFilePath changed"
		Write-Host "Section $sectionName, key: Enabled = false"
    }
	$newConfigContent | Set-Content -Path $configFilePath
}

function Prompt-UrlsFileMissing {
	Write-Host "`nFile $urlsFile is missing."
    $response = Read-Host "Do you want to continue without it? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
		Write-Host "`nContinuing script execution..."
    } else {
		Write-Host "Exiting the script..."
        exit 0
    }
}

function Prompt-ExitConfirmation {
    $response = Read-Host "Do you want to exit? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Exiting the script..."
        exit 0
    } else {
        Write-Host "`nContinuing script execution..."
    }
}


function Show-Menu {
    Write-Host "`nSelect an option:"
    Write-Host "1. Update"
    Write-Host "2. Clean and Update"
    Write-Host "3. Clean"
	Write-Host "4. Show mod list"
    Write-Host "5. Exit"

    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        '1' {
            break
        }
        '2' {
			RemoveAllBepInExItems
            break

        }
        '3' {
			RemoveAllBepInExItems
			Show-Menu
        }
		'4' {
			if (Test-Path $urlsFile) {
				PrintModList
			} else {
				Write-Host "`nFile $urlsFile is missing!"
			}
            Show-Menu
        }
        '5' {
            exit 0
        }
        default {
            Write-Host "Invalid choice! Please enter a valid option."
            Show-Menu
        }
    }
}

function Main {
	if (-not (Test-Path $urlsFile)) {
		Prompt-UrlsFileMissing
	}

	Show-Menu

	if (Test-Path -Path $bepInEx -PathType Container) {
		Write-Host "`nBepInEx mod directory already exists"
		Prompt-ExitConfirmation
		Main
	}

	# Prepare temporary directory
	if (-not (Test-Path -Path $tempRootDir -PathType Container)) {
		New-Item -ItemType Directory -Path $tempRootDir | Out-Null
	} else {
		# Recreate if exists
		Remove-Item -Path $tempRootDir -Force -Recurse
		New-Item -ItemType Directory -Path $tempRootDir | Out-Null
	}

	# Extract BepInExPack
	ExtractBepInExPack

	# Extract LcAPI
	ExtractLcApi

	# Apply mods from file $urlsFile
	if (Test-Path $urlsFile) {
		ApplyModsFromFile
	}

	## Cleanup
	Remove-Item -Path $tempRootDir -Force -Recurse

	Prompt-LoggingConsole
	Write-Host "`nPlugins were added to: $bepInEx"
	Write-Host "Finished!"
	Write-Host "Press Enter or any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 0
}

Write-Host "`nThis script will modify your Lethal Company game"
Write-Host "found game directory: $gameDirectory"
Main





