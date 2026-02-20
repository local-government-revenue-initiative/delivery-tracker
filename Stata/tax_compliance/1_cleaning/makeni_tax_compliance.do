********************************************************************************
********************************************************************************
* 	Filename:		0_Master.do
*	Description:	Setting_up LSMS-ISA Harmonised Panel Analysis Code. 
*  	Modified by:	Robin Benabid Jegaden (r.benabidjegaden@gmail.com)
*   Modified on:	11 Feb 2025
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
	global Build = "${projdir}/data/2_Build/tax_compliance" //temporary data
	global Final = "${projdir}/data/3_Final/tax_compliance" //cleaned data

	
*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Makeni/audit_log_export_09-Oct-2025.xlsx", ///
		sheet("Page 1") cellrange(A5) firstrow clear
	save "${Build}/Makeni/audit_log.dta", replace
	
	use "${Build}/Makeni/audit_log.dta", clear
	drop K
	rename Label id
	save "${Build}/Makeni/audit_log.dta", replace
	
	import excel "${Input}/Makeni/Confirmed_Delivered Letters_2.xlsx", firstrow clear
	save "${Build}/Makeni/delivered_letters.dta", replace
	
	use "${Build}/Makeni/delivered_letters.dta", clear
	rename code id
	duplicates drop id, force
	save "${Build}/Makeni/delivered_letters.dta", replace	

	
	merge 1:m id using "${Build}/Makeni/audit_log.dta"
	drop if _merge!=3
	save "${Final}/Makeni/makeni_compliance_analysis.dta", replace	

		rename startdeliverydate start_date
		rename enddeliverydate end_date
		rename Timestamp payment_date
		order start_date end_date payment_date
		drop if Property!="Payment"
		drop if Action=="UPDATE"
		keep start_date end_date payment_date delivery_type id Actor NewValue
		rename Actor bank
		rename NewValue amount
	save "${Final}/Makeni/makeni_compliance_analysis.dta", replace	

	use "${Final}/Makeni/makeni_compliance_analysis.dta", clear	
		generate payment_date_num = dofc(payment_date)
		format payment_date_num %td
		drop payment_date 
		rename payment_date_num payment_date
		format start_date end_date %td
		order start_date end_date payment_date id delivery_type bank amount
		
		gen status = .
		replace status = 1 if payment_date < start_date
		replace status = 2 if payment_date > start_date
		replace status = 0 if payment_date == .
		
		duplicates drop id, force
	merge 1:1 id using "${Build}/Makeni/delivered_letters.dta"
	keep start_date end_date payment_date id delivery_type bank amount status
	replace status = 0 if status == . 
destring amount, replace
label def status 0 "Remains in default" 1 "Paid before enforcement" 2 "Paid after enforcement"
label val status status



