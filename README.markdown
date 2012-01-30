####Synopsis 
   This program takes as input an HCD file and an ETD file.
   It then filters the HCD file for the presence of ALL the ions provided
   within a given tolerance (either an exact m/z or a ppm value).

####Examples
   Filter the file HCDFile.txt for the presence of 366.14  
   with 0.1 m/z tolerance and output the corresponding ETD 
   spectra from ETDfile.txt to the file ETDout.txt.
>     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14 --mzTol 0.1 --output ETDout.txt

   Other examples:
>     Filter for the presence of both 366.14 AND 407.16 with 0.1 m/z tolerance.
>     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14,407.16 --mzTol 0.1 --output ETDout.txt

     Filter for the presence of both 366.14 AND 407.16 with 200 ppm tolerance.
     > katikruncher --hcd HCDfile.txt --etd ETDfile.txt --mz 366.14,407.16 --mzTol 0.1 --output ETDout.txt

#####Author
   Jamie Sherman

#####Copyright
   Copyright (c) 2011 UCSF. Licensed under the MIT License:
   http://www.opensource.org/licenses/mit-license.php

The following is the output of 
> > katiKruncher.rb --help

Synopsis 
  This program takes as input a pair of files, one 
  HCD file and one ETD file. The files are assumed 
  to correlate meaning the Percursor of HCD scan X 
  is the same precursor in ETD scan X+1. The correlated 
  scans are stored as a pair then the HCD scan is 
  filtered for the presence of ALL the desired ions, 
  if present the scan pair is kept if absent the scan 
  pair is removed. After filtering the remaining ETD 
  scans are written out to either STDOUT or the file 
  name provided.
 
Usage:
> katikruncher --option Value

  Options --hcd, --etd, --mz and either --mzTol or 
  --ppmTol are required

Examples
  
  Filter the file HCD.txt for the presence of 366.14  
  with 0.1 m/z tolerance and output the corresponding ETD 
  spectra from ETD.txt to the file OUT.txt.

> katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14 --mzTol 0.1 --out OUT.txt
 
  Other examples:
    Filter for the presence of both 366.14 AND 407.16 
    with 0.1 m/z tolerance.
  
> katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14,407.16 --mzTol 0.1 --out OUT.txt
 
    Filter for the presence of both 366.14 AND 407.16 with 
    200 ppm tolerance.
  
> katikruncher --hcd HCD.txt --etd ETD.txt --mz 366.14,407.16 --ppmTol 200 --out OUT.txt
 
Author
  Jamie Sherman
 
Flags:
 
       --hcd HCDFILENAME            The HCD file to filter for the 
                                    perscibed m/z values.
       --etd ETDFILENAME            The corrolated ETD file.
       --mz F1,F2,F3                The fragments to test for in the 
                                    HCD file (All must be present).
       --mzTol DELTAMZ              The tolerance to allow for the m/z 
                                    values from --mz above.
       --ppmTol [PPM]               The tolerance in Parts Per Million for 
                                    the m/z values entered.
       --keepN NUM                  [optional] The fragment to match must be on 
                                    of the NUM most abundant.
       --out FILENAME               Write the scans to FILENAME. 
                                    Write to terminal otherwise.
   -h, --help                       This help page.

