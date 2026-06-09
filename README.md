# Windows-ultimate-cache-cleaner (I guess)
[![Windows](https://custom-icon-badges.demolab.com/badge/Windows-0078D6?logo=windows11&logoColor=white)](#)
[![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=fff)](#)

I made a basic python script to go throughout all the cache directories on windows (all that i knew and researched) and delete them all ,
for some it needs to be "Run as administrator".
## How to use

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

>[!TIP]
> It is advised to look at the script before executing it , just to know what will be deleted and/or exclude some paths that you may want to keep


> [!CAUTION]
> It will delete the pre-compiled shaders, so when you enter a game you have to wait until it pre-compile shaders again
> it will also log you out of steam , so dont be scared
