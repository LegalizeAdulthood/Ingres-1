$ goto DECLARATIONS
$!-----------------------+
$! Name:    CHKDUPFIL.COM
$!
$!
$! Description:
$!
$!      This command procedure is used during the distribution kit build
$!  process, prior to invoking SPKITBLD.  It renames duplicate files
$!  in the kit with unique names by appending the file's home directory to
$!  it's extension.
$!
$!      The following processing is performed:
$!
$!          * dump a list of all packages from the INGRES manifest file,
$!
$!          * dump a complete manifest file listing by feeding the above 
$!            to IIMANINF,
$!
$!          * sort the above file listing by filename,
$!
$!          * read through the sorted listing checking for duplicate 
$!            filenames,
$!
$!          * for each duplicate filename found, rename the file by 
$!            appending the file's home directory to it's extension,
$!
$!          * create a list of the renamed files so that KITINSTAL can 
$!            rename them back to their original "duplicate" filenames.
$!
$!
$! History:
$!  12-Jul-1993 (robynch)
$!      Created.
$!  10-Sep-1993 (robynch)
$!      Change how we sort the manifest output file.  In addition to the
$!      primary ascending sort on filename, we also do a secondary descending 
$!      sort on the directory.  The end result accomplishes a new requirement
$!      not to rename message files in [.A.INSTALL], because they are
$!      used by IIMANINF as soon as VMSINSTAL starts.
$!  26-oct-1993 (ricka)
$!	saveset "A" now going under [INGRES.INSTALL] instead of [INSTALL]
$!	changed location of IIMANINF and RENAMED.LST.
$!  27-oct-1993 (huffman)
$!	Use symbol defined in CPE_BUILDENV_LOCALS.COM, instead of hard
$!	coded symbols.
$!  02-Nov-1993 (robynch)
$!      Adjust the sort key positions to the output generated by the new     
$!      -unique flag from IIMANINF.  A saveset location now prefaces the
$!      directory name.
$!  15-jan-1996 (dougb)
$!	Don't go into an endless loop when a sub-directory of FRONT_STAGE
$!	doesn't (yet) exist.  Remove most INQUIRE statements -- this gets
$!	run as a sub-process (not interactive).
$!	Use the new "-all" option to IIMANINF when getting the list of
$!	packages.  We want everything any (custom or streamlined)
$!	installation might require.
$!   17-jun-2001 (kinte01)
$!	Setup for multiple product builds
$!   05-jul-2001 (kinte01)
$!	To work around the fact the -location doesn't work for iimaninf
$!	force the definition of (prog1prfx)_manifest_dir to be defined.  
$!   18-Nov-2009 (horda03)
$!      On a clustered environment GET_DEVNAME goes into an infinite loop. A device
$!      can either have the node name or the node number, however the full device
$!      name will be the node number, hence if the path supplied the device using
$!      the node name (ukan02$dka300: as opposed to $2$dka300:) the spin occurs.
$!-----------------------+
$!
$ DECLARATIONS:
$   set noon
$   on control_y then goto CTRL_Y
$   on error then goto GENERAL_ERROR
$!
$   msg_qual    = f$environment("MESSAGE")
$   THIS_THANG  = f$parse(f$environment("PROCEDURE"),,,"NAME")
$!                
$   SAVELIST    = "A/B/C/D/E"
$   reldir = f$trnlnm("II_RELEASE_DIR")
$   D_SAVEROOT  = f$parse(reldir,,,"device","no_conceal") + -
	f$parse(reldir,,,"directory","no_conceal") - "]["
$      product 	= "INGRES"
$      prev_manifest_loc = F$TRNLNM("II_MANIFEST_DIR")
$!
$   define/nolog/process    PKGFIL      "SYS$SCRATCH:PACKAGE.LST;"
$   define/nolog/process    FILES       "SYS$SCRATCH:FILES.LST;"
$   define/nolog/process    SORTED      "SYS$SCRATCH:FILES_SORTED.LST;"
$   define/nolog/process    DUPS        "A_ROOT:[''product'.INSTALL]RENAMED.LST"
$!
$   here = f$parse(f$environment("PROCEDURE"),,,"DEVICE")
$   here = here+f$parse(f$environment("PROCEDURE"),,,"DIRECTORY")
$   define/nolog/process    FDLFIL      "''here'RENAMED.FDL"
$!
$   DIRNAME     == ""
$   DEVNAME     == ""
$   cy          == 0
$!
$!
$ GET_INPUT:
$   write sys$output " "
$   write sys$output " ''THIS_THANG' -- Check for duplicate file names."
$   write sys$output " "
$   GOTO Get_Parent
$!
$ Get_Saveset_Parent:
$   $STATUS = 2320		! SS$_NOSUCHFILE
$   GOTO GENERAL_ERROR
$!
$ Get_Parent:
$   write sys$output ""
$   write sys$output "Using ''D_SAVEROOT' as Saveset areas..."
$   write sys$output ""
$   DUMMY = "''D_SAVEROOT'"
$   call GET_DIRNAME "''DUMMY'"
$   if cy then goto CTRL_Y
$   if f$locate(".",DUMMY) .ne. f$length(DUMMY)
$   then
$       DNAM = "''f$extract(0,f$locate(DIRNAME,DUMMY)-1,DUMMY)']''DIRNAME'.dir"
$   else
$       ROOT = f$trnlnm("''f$extract(0, f$locate(":",DUMMY), DUMMY)'")
$       DNAM = "''f$extract(0,f$length(ROOT)-2,ROOT)']''DIRNAME'.dir"
$   endif
$!
$   if f$search("''DNAM'") .eqs. ""
$   then
$       write sys$output " "
$       write sys$output "''DNAM' not found.  Please respecify."
$       goto Get_Saveset_Parent
$   else
$       call GET_DEVNAME 'DUMMY'
$       if cy then goto CTRL_Y
$       DUMMY = "''DEVNAME']"
$       define/process/nolog SAVE_ROOT 'DUMMY'/trans=(conceal,terminal)
$   endif
$!
$ Check_Derived_files:
$!
$   DUMMY   = f$trnlnm("SAVE_ROOT")
$   DUMMY   = "''f$extract(0,f$length(DUMMY)-1,DUMMY)'A.''product'.INSTALL]"
$   goto Chk_imtloc
$!
$ Get_imtloc:
$   $STATUS = 2320		! SS$_NOSUCHFILE
$   GOTO GENERAL_ERROR
$!
$ Chk_imtloc:
$   if f$search("''DUMMY'IIMANINF.EXE") .eqs. ""
$   then
$       write sys$output " "
$       write sys$output "''DUMMY'IIMANINF.EXE not found.  Please respecify."
$       goto Get_imtloc
$   else
$       IMT    = "$''DUMMY'IIMANINF"
$   endif
$!
$   DUMMY   = f$trnlnm("SAVE_ROOT")
$   DUMMY   = "''f$extract(0,f$length(DUMMY)-1,DUMMY)'A.''product'.INSTALL]"
$   goto Chk_manloc
$!
$ Get_manloc:
$   $STATUS = 2320		! SS$_NOSUCHFILE
$   GOTO GENERAL_ERROR
$!
$ Chk_manloc:
$   if f$search("''DUMMY'RELEASE.DAT") .eqs. ""
$   then
$       write sys$output " "
$       write sys$output "''DUMMY'RELEASE.DAT not found.  Please respecify."
$       goto Get_manloc
$   else
$       define/nolog/process    MANLOC  'DUMMY'
$       define/nolog/process    II_MANIFEST_DIR 'DUMMY'
$   endif
$!    
$ IDX = 0
$ Check_Saveset_Loop:
$   SS = f$element(idx,"/",SAVELIST)
$   if SS .nes. "/" 
$   then
$       call GET_SAVELOC 'SS'
$       if cy then goto CTRL_Y
$       IDX = IDX + 1
$       goto Check_Saveset_Loop
$   endif
$!
$!
$ DUMP_PACKAGES:
$!      
$!      First, we need a complete list of packages in RELEASE.DAT.  We
$!      get this by extracting the package names from the listing produced
$!      by IIMANINF.
$!
$!
$   write sys$output ""
$   write sys$output "Creating manifest list files . . ."
$!
$   IMT -all -loc=MANLOC -out=PKGFIL
$!
$!      Open the file and gobble the first two header lines
$!
$   open/read/error=PKGFIL_ERROR    I_FILE  PKGFIL
$   read/error=PKGFIL_ERROR/end=End_Loop_Pkg I_FILE IREC
$   read/error=PKGFIL_ERROR/end=End_Loop_Pkg I_FILE IREC
$   PLST = ""
$   PKG  = ""
$   Loop_Pkg:
$       read/error=PKGFIL_ERROR/end=End_Loop_Pkg I_FILE IREC
$       PKG = f$element(0, " ", f$edit(IREC,"COMPRESS,UNCOMMENT,TRIM,UPCASE"))
$       if PLST .eqs. ""
$       then
$           PLST = PKG
$       else
$           PLST = PLST + "," + PKG
$       endif
$       goto Loop_Pkg
$   End_Loop_Pkg:
$!
$ DUMP_PACKAGE_FILES:
$!
$!      Now we get a complete file listing by feeding the package list 
$!      created above to IIMANINF.  We sort this list by filename for
$!      the next operation.
$!
$!
$   if PLST .eqs. "" then goto NO_PLST
$   IMT -unique='PLST -loc=MANLOC -out=FILES
$   set message/nofac/noid/nosev/notext
$   sort/stable /key=(pos:45,siz:39,num:1,char,asc) -
                /key=(pos:1,siz:44,num:2,char,asc) -
                FILES     SORTED
$!              
$   set message'msg_qual'
$!
$ FIND_DUPLICATES:
$!
$!      Finally, we read through the sorted file listing created above
$!      and look for duplicate filenames.  We do this by simply comparing
$!      the currently read filename with the previously read filename.
$!      When a duplicate is found, we rename it to a filename with its
$!      home directory appended to its extention.  For each file that is 
$!      renamed, we log the directory, original name, and "temporary"
$!      unique name into a file so that KITINSTAL can rename the file
$!      back to its original name during the installation.
$!
$!
$   write sys$output ""
$   write sys$output "Searching for duplicates . . ."
$!
$   open/read/error=SORTED_ERROR    S_FILE  SORTED
$   open/write/error=DUPS_ERROR     D_FILE  DUPS
$   LNAM = ""
$   Loop_Sorted:
$       read/error=SORTED_ERROR/end=End_Loop_Sorted S_FILE IREC
$       FNAM = f$element(2, " ", f$edit(IREC, "COMPRESS,UNCOMMENT,TRIM,UPCASE"))
$       if FNAM .eqs. LNAM
$       then
$           DNAM = f$edit( f$extract(2,42,IREC), "COLLAPSE" )
$           call GET_DIRNAME 'DNAM'
$           if cy then goto CTRL_Y
$!
$           DUPNAM = "''FNAM'-''DIRNAME'"
$           FND = 0
$           IDX = 1
$           Find_Oldfile_Loop:
$               SS = f$element(IDX,"/",SAVELIST)
$               if SS .eqs. "/" then goto End_Find
$               OLDNAM = "''SS'_ROOT:''DNAM'''FNAM'"
$               if f$search("''OLDNAM'") .nes. ""
$               then
$                   FND = 1
$                   goto End_Find
$               else
$                   IDX = IDX + 1
$                   goto Find_Oldfile_Loop
$               endif
$           End_Find:
$!
$           if .not. FND
$           then
$               write sys$output "Warning -- ''FNAM' not found.  RENAME not done!"
$           else
$               rename/log 'OLDNAM' 'DUPNAM'
$           endif
$!
$           OREC = ""
$           OREC[0,89] := "''f$edit( f$extract(2,f$length(IREC),IREC), "COLLAPSE,UNCOMMENT,TRIM,UPCASE" )'"
$           OREC[90,'f$length(DUPNAM)'] := "''DUPNAM'"
$           write/error=DUPS_ERROR D_FILE OREC
$!
$       endif
$       LNAM = FNAM
$       goto Loop_Sorted
$   End_Loop_Sorted:
$   close/error=DUPS_ERROR  D_FILE
$!
$ CONVERT_RENAME_FILE:
$!
$!      Now we convert the output listing file, RENAMED.LST above to
$!      an ISAM file format to make life easier for KITINSTAL when it
$!      generates the "provide file."
$!
$!
$   write sys$output ""
$   write sys$output "Converting ''f$trnlnm(""DUPS"")' file to ISAM format . . ."
$!
$!      If the FDL file doesn't exist in the same location as this procedure,
$!      then just create it...
$!
$   if f$search("FDLFIL") .eqs. ""
$   then
$       open/write/error=FDL_ERROR O_FILE FDLFIL
$!
$       write/error=FDL_ERROR O_FILE "FILE"
$       write/error=FDL_ERROR O_FILE "    ORGANIZATION        indexed"
$       write/error=FDL_ERROR O_FILE "RECORD"
$       write/error=FDL_ERROR O_FILE "    CARRIAGE_CONTROL    carriage_return"
$       write/error=FDL_ERROR O_FILE "    FORMAT              variable"
$       write/error=FDL_ERROR O_FILE "    SIZE                250"
$       write/error=FDL_ERROR O_FILE "AREA 0"
$       write/error=FDL_ERROR O_FILE "    ALLOCATION          51"
$       write/error=FDL_ERROR O_FILE "    BEST_TRY_CONTIGUOUS yes"
$       write/error=FDL_ERROR O_FILE "    BUCKET_SIZE         3"
$       write/error=FDL_ERROR O_FILE "    EXTENSION           12"
$       write/error=FDL_ERROR O_FILE "AREA 1"
$       write/error=FDL_ERROR O_FILE "    ALLOCATION          6"
$       write/error=FDL_ERROR O_FILE "    BEST_TRY_CONTIGUOUS yes"
$       write/error=FDL_ERROR O_FILE "    BUCKET_SIZE         3"
$       write/error=FDL_ERROR O_FILE "    EXTENSION           3"
$       write/error=FDL_ERROR O_FILE "KEY 0"
$       write/error=FDL_ERROR O_FILE "    CHANGES             no"
$       write/error=FDL_ERROR O_FILE "    DATA_AREA           0"
$       write/error=FDL_ERROR O_FILE "    DATA_FILL           75"
$       write/error=FDL_ERROR O_FILE "    DATA_KEY_COMPRESSION        yes"
$       write/error=FDL_ERROR O_FILE "    DATA_RECORD_COMPRESSION     yes"
$       write/error=FDL_ERROR O_FILE "    DUPLICATES          no"
$       write/error=FDL_ERROR O_FILE "    INDEX_AREA          1"
$       write/error=FDL_ERROR O_FILE "    INDEX_COMPRESSION   yes"
$       write/error=FDL_ERROR O_FILE "    INDEX_FILL          75"
$       write/error=FDL_ERROR O_FILE "    LEVEL1_INDEX_AREA   1"
$       write/error=FDL_ERROR O_FILE "    PROLOG              3"
$       write/error=FDL_ERROR O_FILE "    SEG0_LENGTH         90"
$       write/error=FDL_ERROR O_FILE "    SEG0_POSITION       0"
$       write/error=FDL_ERROR O_FILE "    TYPE                string"
$!
$       close/error=FDL_ERROR   O_FILE
$   endif
$!
$!      Now simply convert the file...
$!
$   convert/nostatistics/fdl=FDLFIL    DUPS    DUPS
$!
$   goto CLEANUP
$!
$!
$!          * * *   ERROR HANDLING ROUTINES    * * *
$!
$ CTRL_Y:
$   write sys$output "Interrupt entered, ''THIS_THANG' aborting . . ."
$   goto CLEANUP
$!
$ GENERAL_ERROR:
$   errmsg = f$message($status)
$   write sys$output ""
$   write sys$output "WARNING -- An error occured in ''THIS_THANG'; aborting."
$   write sys$output "''errmsg'"
$   write sys$output ""
$   goto CLEANUP
$!
$ PKGFIL_ERROR:
$   errmsg = f$message($status)
$   write sys$output ""
$   write sys$output "WARNING -- Error while processing ''f$trnlnm(""PKGFIL"")'; aborting."
$   write sys$output "''errmsg'"
$   write sys$output ""
$   goto CLEANUP
$!
$ NO_PLST:
$   write sys$output ""
$   write sys$output "WARNING -- Zero items found in packages list; aborting."
$   write sys$output ""
$   goto CLEANUP
$!
$ SORTED_ERROR:
$   errmsg = f$message($status)
$   write sys$output ""
$   write sys$output "WARNING -- Error while processing ''f$trnlnm(""SORTED"")'; aborting."
$   write sys$output "''errmsg'"
$   write sys$output ""
$   goto CLEANUP
$!
$ DUPS_ERROR:
$   errmsg = f$message($status)
$   write sys$output ""
$   write sys$output "WARNING -- Error while processing ''f$trnlnm(""DUPS"")'; aborting."
$   write sys$output "''errmsg'"
$   write sys$output ""
$   goto CLEANUP
$!
$ FDL_ERROR:
$   errmsg = f$message($status)
$   write sys$output ""
$   write sys$output "WARNING -- Error while processing ''f$trnlnm(""FDLFIL"")'; aborting."
$   write sys$output "''errmsg'"
$   write sys$output ""
$   goto CLEANUP
$!
$!
$ CLEANUP:
$   set noon
$   set message/noid/nosev/notext/nofac
$!
$   close   I_FILE
$   close   S_FILE
$   close   D_FILE
$   close   O_FILE
$!
$!   delete/nolog    PKGFIL
$!   delete/nolog    FILES
$!   delete/nolog    SORTED
$!   purge/nolog     DUPS
$!   purge/nolog     FDLFIL
$!
$   idx = 0
$   Deassign_Loop:
$       item = f$element(idx,"/",SAVELIST)
$       if item .eqs. "/" then goto End_deassign
$       deassign/process 'item'_ROOT
$       idx = idx + 1
$       goto Deassign_Loop
$   End_deassign:
$!
$   deassign/process            SAVE_ROOT
$   deassign/process            PKGFIL
$   deassign/process            FILES
$   deassign/process            SORTED
$   deassign/process            DUPS
$   deassign/process            MANLOC
$   deassign/process            FDLFIL
$   delete/symbol/global/nolog  cy
$   delete/symbol/global/nolog  DEVNAME
$   delete/symbol/global/nolog  DEVNAME
$   define/process		II_MANIFEST_DIR 'prev_manifest_loc'
$!
$   set message'msg_qual'
$!
$   write sys$output ""
$   write sys$output " ''THIS_THANG' complete."
$   write sys$output ""
$   EXIT
$!
$!-----------------------+
$!      SUBROUTINES      |
$!-----------------------+
$ GET_SAVELOC:  SUBROUTINE
$!
$!      Subroutine to verify the existence of the inputted saveset area.
$!
$!
$   cy == 0
$   on error then EXIT
$   on control_y then goto CTL_Y
$!
$   DIRNAME == P1
$   DUMMY = "SAVE_ROOT:[''DIRNAME']"
$
$   if f$locate(".",DUMMY) .ne. f$length(DUMMY)
$   then
$       DNAM = "''f$extract(0,f$locate(DIRNAME,DUMMY)-1,DUMMY)']''DIRNAME'.DIR"
$   else
$       ROOT = f$trnlnm("''f$extract(0, f$locate(":",DUMMY), DUMMY)'")
$       DNAM = "''f$extract(0,f$length(ROOT)-2,ROOT)']''DIRNAME'.DIR"
$   endif
$!
$   if f$search("''DNAM'") .eqs. ""
$   then
$       write sys$output " "
$       write sys$output "''DNAM' not found.  Skipping this directory."
$       define/process/nolog 'p1'_ROOT NL:
$   else
$       call GET_DEVNAME 'DUMMY'
$       if cy then goto CTRL_Y
$       DUMMY = "''DEVNAME']"
$       define/process/nolog 'P1'_ROOT 'DUMMY'/trans=(conceal,terminal)
$   endif
$   EXIT
$!
$ CTL_Y:
$   cy == 1
$   EXIT
$ ENDSUBROUTINE
$!-----------------------+
$ GET_DIRNAME: SUBROUTINE
$!
$!      Subroutine to extract the trailing directory name from a
$!      directory specification.
$!
$!
$   cy == 0
$   on error then EXIT
$   on control_y then goto CTL_Y
$!
$   IDX = 0
$   DR = ""
$   DIRNAME == ""
$   P1 = f$edit(P1,"COLLAPSE")
$   if f$locate(".",P1) .eq. f$length(P1)
$   then
$       DR = f$parse(P1,,,"DIRECTORY")
$       DIRNAME == f$extract( 1, f$length(DR)-2, DR )
$       goto end_dloop
$   endif
$!
$   dloop:
$       DR = f$edit( f$element(IDX, ".", P1), "COLLAPSE" )
$       if DR .eqs. "." 
$       then 
$           goto end_dloop
$       else
$           DIRNAME == f$extract( 0, f$length(DR)-1, DR)
$       endif
$       IDX = IDX + 1
$       goto dloop
$   end_dloop:
$   EXIT
$!
$ CTL_Y:
$   cy == 1
$   EXIT
$ ENDSUBROUTINE
$!-----------------------+
$ GET_DEVNAME: SUBROUTINE
$!
$!      Subroutine to extract a rooted logical and decompose it down
$!      to a physical device.
$!
$!
$   cy == 0
$
$   DEVNAME == F$PARSE( "''P1'",,,,"NO_CONCEAL,SYNTAX_ONLY") - "][" - "].;" + "."
$!
$   EXIT
$ ENDSUBROUTINE
