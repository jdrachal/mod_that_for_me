
# ModThatForMe!
## Script allows configure mods easly for you and your friends

## Usage
1. Put mod_that_for_me.ps1 and mod_urls.txt in your Lethal Company directory
2. Paste URLs to all mods in mod_urls.txt
2. Open Powershell Console as Administrator
3. call:
Set-ExecutionPolicy RemoteSigned
.\mod_that_for_me.ps1
4. To force process even if mod directory is already there you can call
.\mod_that_for_me.ps1 -Force
5. To clean mods you can call
.\mod_that_for_me.ps1 -Clean
