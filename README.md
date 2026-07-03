# Some sort of basic System maintenance for windows and linux (I use it myself)
[![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](#)
[![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)](#)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](#)
[![Bash](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)](#)

I made a basic python / bash script to go throughout =>
- All the cache directories on windows (all that i knew and researched) and delete them all ,for some it needs to be "Run as administrator".
- All the updates,upgrades,broken installs and caches, it needs "sudo".
## How to use

# Windows =
Main =>
Step 1 : Have python on your windows.
Step 2 : Open a powershell or cmd as administrator go to the location where you have this script saved/downloaded then just type
``` python
py cleaner.py
```

Alternative =>
Step 1 : Go to the location where you have this script saved/downloaded.
Step 2 : Hold Shift then right click and choose copy as path.
Step 3 : Open a powershell or cmd as administrator then just type 
``` python
exec(open(r"location").read())
```
Change/Replace "location" with/to the location you copied using Step 2.

# Linux =
Main =>
Make it executable with
``` Bash
chmod +x system-maintenance.sh
```
and run it 
``` Bash
./system-maintenance.sh
```

>[!TIP]
> It is advised to look at the script before executing it , just to know what will be deleted and/or exclude some paths that you may want to keep.
> For Linux, pleaseeee dont do anything while updating, the script is so fragile , that when you do anything , even moving a file it can brake everything, didnt really have the skills yet for each edge case.


> [!CAUTION]
> On windows =>
> - It will delete the pre-compiled shaders, so when you enter a game you have to wait until it pre-compile shaders again.
> - It will also log you out of steam , so dont be scared.
> - Don't run this mid windows update, it will force the update to redownload.
