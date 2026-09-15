------------------------------------------
    About UGL
------------------------------------------
    
    UGL is a game development library for qb. It's similar to 
    allegro and is what we think a gamedev library should be like. 
    It's not yet complete, but almost.
    
    UGL is completly free and we do not take any responsibility for
    any damage it might do. Nor do we take any responsibility for 
    how people use it.
    
    To contact the authors:
    v1ctor:     av1ctor@yahoo.com.br
    Blitz :     blitz.dotnet@stockholm.bonet.se
    

------------------------------------------
    How to use the custom library builder
------------------------------------------
    
    It's very simple.
        - Start lib\uglbuild.exe
        
        - Select the compiler you want to build for
          options -> build target
          
        - Set the paths to the compiler (bin path not needed)
          options -> path
          click on the button with 3 dots on to get the file
          dialog box
          
        - Select to build debug/release library
          options -> build type          
    
        - Select the routines to include
        
        - Click on build
        
    All your options are saved.        
    
        
------------------------------------------
    Note to Windows NT/2000/XP users
------------------------------------------
    
    * Enable EMS memory
    
        1st) using Windows Explorer, go to the %SystemRoot% path 
             (normally: C:\WINNT);
    
        2nd) find the "_default" PIF file;
    
        3rd) right-click it and select "Properties" in the pop-up menu;
    
        4th) at "Memory" tab, set the "Total" box to 16384 (for a system with
             only 32Mb of physical memory; set to 32768 if it has more) on the
             "Expanded (EMS) Memory" group;
    
        5th) press "OK" button :P;
        
    * Run your application in fullscreen or windows will report that your
      video card is not VESA compatible
      

------------------------------------------
    Note to Windows ME users
------------------------------------------    
    This is how you enable EMS under windows ME (from microsoft 
    knowledge base).

    This article was previously published under Q275423
    
    SYMPTOMS
        You may experience any of the following symptoms: 
        An MS-DOS-based program that requires expanded (EMS) memory may not run
        in Windows Millennium Edition (Me). The expanded (EMS) memory option is 
        unavailable on the Memory tab when you right-click the shortcut to an MS-DOS
        based program and then click Properties. Your computer hangs when you start
        it with a Windows Me Startup disk that attempts to load Emm386.exe from the
        Windows Me folder by using the Config.sys file on the Startup disk.
        
    CAUSE
        There is an EmmExclude or NoEMSDriver statement in your System.ini file, or
        your system may have insufficient upper memory area available for Windows to
        provide EMS memory in Windows. Windows Me does not support loading Emm386.exe
        from the Startup disk. 
        
    RESOLUTION
        To work around this behavior, run your MS-DOS-based program in Windows after
        disabling any EmmExclude or NoEMSDriver statements in the System.ini file by
        following these steps: 
        
        - On the toolbar click Start, click Run, type System.ini, and then click OK.
        
        - Find the EmmExclude or NoEMSDriver statement in the [386enh] section, and
          then type a semicolon (;) at the beginning of the line.
        
        - Save the file and then restart your computer.
    
    NOTE: An example of an EmmExclude entry is "EMMExclude=C000-CFFF". If this does
          not resolve the issue, add a "ReservePageFrame=yes" statement to the [386enh]
          section of the System.ini file. If this does not resolve the issue, your system
          may have insufficient upper memory blocks available for Windows Me to provide 
          EMS memory in Windows. Due to the removal of real mode support in Windows Me,
          this problem can occur even if Windows 95 or Windows 98 was able to provide EMS
          memory in Windows.For additional information about the removal of real mode support
          in Windows Me, click the article number below to view the article in the Microsoft
          Knowledge Base: 269524 Overview of Real Mode Removal from Windows Millennium Edition 
    
    NOTE: If you are unable to obtain EMS support in Windows Me by using the preceding steps, 
          then you can run your MS-DOS-based program in real mode after starting your computer
          with a Windows 95B (OEM Service Release 2), Windows 95C (OEM Service Release 2.5), 
          Windows 98, or Windows 98 Second Edition Startup disk that provides EMS support by
          using the versions of Himem.sys and Emm386.exe that are included with one of these
          previous versions of Windows. Also, MS-DOS and Windows 95 versions prior to Windows
          95B do not support the FAT32 file system. If the hard drive on your Windows Me computer
          is using the FAT32 file system, you will not be able to use it if you boot with an 
          MS-DOS or Windows 95 Startup Disk.
      


------------------------------------------
    Note on compiling
------------------------------------------              

    The microsoft linker standard segment limit is too low, so
    when you try to compile you'll get an error saying too many 
    segments. This problem can be solved in two ways:
    
    Solution one:    
        The is in my opnion the best solution. What you do is compile
        and link manually and with the linker use the /seg:800 option
        with pds/vbdos and /segments:800 if you're using qb 4.5. You 
        can do this with the mk4qb.bat/mk4pds.bat/mk4vbd.bat in the 
        exs directory. Just make sure to change the path to the standard
        qb lib. 

    Solution Two:
        Use the library builder to exclude anything you don't need. For 
        instance if you're only going to use 8 bit modes, exclude 15, 16 
        and 32 bit. Likewise with anything else you don't need.    
    
    


------------------------------------------
    Note to C coders making libs that will be used in/with QB
------------------------------------------              
    
    Because the difference between C and BASIC strings, if you are
    going to make a C lib to be used by QB/PDS/VBD programs, and if
    calls to UGL routines that have strings as arguments are done, the
    __BASLIB__ constant must be defined before including any header
    that is part of UGL, or calling those routines will not work as
    the arguments will be wrong (probably causing a crash). There's
    an example at the exs\c\c_bas dir.


------------------------------------------
    Note about sound in win 9x
------------------------------------------
    
    Windows 9x has legalcy sound support. However, some cards (such as
    all the PCI sound blaster cards) need to have special drivers 
    installed for it to work. These drivers are usally found on the 
    driver disc that comes with the card. Otherwise try the vendors site.
    Or if you can't find them try contacting the vendor.

    
------------------------------------------
    Note about sound in win NT/2k/XP
------------------------------------------
    
    Windows NT and 2000 does not have legalcy sound support. Windows
    XP on the other hand does. But it's very limited and has very poor
    quality. So in all cases you'll need to use VDM Sound. This is a 
    excellent legalcy sound emu for NT based OSes. 
    
    You can get VDM Sound from http://ntvdm.cjb.net
    
    Or to people who have a hard time navigating through web 
    sites use the link below which goes direct to the download.
        
    https://sourceforge.net/project/showfiles.php?group_id=20091&release_id=46941
    
    Once you have installed VDM Sound you'll have to run dosdrv.exe from
    the command prompt before attempting to use sound. So it doesn't load
    automatically, try to remember that before sending us mails that the
    sound module doesn't work. But if you've done this and you still have
    problems feel free to mail us.

    
------------------------------------------
    Note about music
------------------------------------------

    At the release of 0.22, arpeggio, vibrato and tremolo has not 
    been implemented yet. Also, the music module uses the UGL timer.
    So once you started the music module you won't be able to use 
    qb's timer, sound or play commands. But who needs them anyway?
    You will of course be able to use UGLs timer module as usual.
    
    In NT/2K/XP the music might run slightly uneven. But you won't 
    notice it unless you know the song really well and listen to it
    carefully. Unfortuneatly there's nothing I can do about this, as
    it's becuase NT/2K/XP has bad PIT emulation. But it's nothing
    to worry about.    


------------------------------------------
    Final words
------------------------------------------              

    UGL does not use any hacks and it follows the VESA standard
    100%. So if there are any incompatibility problems, it's not
    our fault. 
    
    The manual is not complete, but there are enough docs to be
    able to do what you need to do.