********************************************************************************
********************************************************************************
* 	Filename:		0_Master.do
*	Description:	Environment set-up for FCC revenue reporting. 
*  	Modified by:	Robin Benabid Jegaden (r.benabidjegaden@gmail.com)
*   Modified on:	01 Oct 2025
*	Stata version:	15.1
********************************************************************************
********************************************************************************

cap log close _all
clear all
set more off
*set maxvar 5000 //if needed
*set matsize 11000 //if needed
set type double
set trace off 
pause on //to keep to be able to define parameters

//Please add your directory below to reflect your system path. This will apply the path to all files.

* 0. Select user.
*****************

	if "`c(username)'" == "robin" {
		global projdir "D:/Dropbox/LoGRI/Sierra_Leone"
	}	

* 1. Global Pathways.
*********************
	global Do = "${projdir}/code/Stata/tax_compliance" //dofiles
	global Input = "${projdir}/data/1_Raw/tax_compliance" //raw data
	global Temp = "${projdir}/data/2_Build/tax_compliance" //temporary data
	global Final = "${projdir}/data/3_Final/tax_compliance" //cleaned data
	adopath ++ "${Do}/ado" //modify ado storage path

* 2. Package Set-up.
********************
	local ssc_packages "reghdfe ftools geodist shp2dta estout outtable mmat2tex revrs distplot blindschemes binscatter cibar cipolate ciplot vioplot cem texdoc egenmore reshape outreg2 tabout rdrobust mylabels winsor2 putdocx colrspace bs4rw distinct egenmore epctile extremes fre insob lgraph mdesc mmerge myaxis mypkg palettes psmatch2 rmse spmap wbopendata winsor2 xtgcause zscore06"
	* install using ssc, but avoid re-installing if already present
	foreach pkg in `ssc_packages' {
		capture which `pkg'
		if _rc == 111 {                 
			dis "Installing `pkg'"
			quietly ssc install `pkg', replace
		}
	}

***************************************************************************************************************************
di "Do you want to run all the cleanings (1), only those needed for our analysis (2), or just generate the estimates (0)? " 
"Modify the line below accordingly"
pause "Then, press q HERE to continue..."
gl cleaning = 2 //to be modified (=0, 1 or 2) if you want to run the cleaning again or to simply generate estimations.
***************************************************************************************************************************

* 3. Run all cleaning files.	
****************************	
	if $cleaning == 0 {
	*** Generic functions ***
	do "${Do}/Build/LSMS/1_Programs.do"
	*** Cleaning All ***
	do "${Do}/Build/LSMS/2_Cleaning_ALL.do"
	*** Appending ALL ***
	do "${Do}/Build/LSMS/3_Append_ALL.do"
}
	
	if $cleaning == 0 | $cleaning == 1 {
	*** Cleaning of specific country inputs ***
	do "${Do}/Build/LSMS/4_Country_input.do"
		*Malawi.do 	 -->  Malawi.dta
		*Tanzania.do -->  Tanzania.dta
		*Uganda.do   -->  Uganda.dta
		*Nigeria.do  -->  Nigeria.dta (from R)
		*Ethiopia.do -->  Ethiopia.dta (from R)
	*** Building Shift-Share instruments ***
	do "${Do}/Build/LSMS/5_Migration_shift_share.do"
	do "${Do}/Build/LSMS/6_Trade_shift_share.do"
		*Check 3_Common_sub/Setup_ctry_param.do 
		*to define country specific parameters for analysis
	*** Merging Migration/Trade shift-share dataset ***
	do "${Do}/Build/LSMS/7_Merge_shift_share.do"
	*** Cleaning agricultural outcomes ***
	do "${Do}/Build/LSMS/8_Agricultural_output.do"	
	*** Merging Final dataset ***
	do "${Do}/Build/LSMS/9_Merge_ALL.do"
}

* 4. Generate Outcomes.
*********************
	if $cleaning == 0 | $cleaning == 1 | $cleaning == 2 {
	*** Generating Figures ***
	do "${Do}/Build/LSMS/10_Figures.do"
	*** Generating Tables ***
	do "${Do}/Build/LSMS/11_Tables.do"
}
