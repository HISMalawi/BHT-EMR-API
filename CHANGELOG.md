# Changelog

This file tracks all changes to the BHT-EMR-API. Changes are grouped under
the following tags: `Fixed`, `Added`, `Deprecated`, and `Removed`. All bug
fixes are listed under `Fixed`. New features and any other additions
are placed under `Added`. For all features marked for removal in a future
version, `Deprecated`, is used. Anything removed in a particular version
is placed under `Removed`.

For versioning, BHT-EMR-API follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
In short, a version number is of the following format `major.minor.patch`
(eg 4.10.7). The patch number changes whenever minor bugs are fixed. The
minor number changes with new backward compatible features. The major
number changes with major changes that completely break backwards
compatibility (examples of this include major architectural changes).
## [Unreleased]

### Added

- ART: Active filing number archiving candidates preferring oldest filing numbers and patients who changed state earliest

### Fixed

- Lab: Random hangs when pushing orders to LIMS (see Lab's [CHANGELOG](https://github.com/EGPAFMalawiHIS/his_emr_api_lab/blob/main/CHANGELOG.md#v1116---2021-10-18))

## v4.12.2 - 2021-10-13

### Fixed

- Lab: Error on push of orders to LIMS immediately after creation (see Lab's [CHANGELOG](https://github.com/EGPAFMalawiHIS/his_emr_api_lab/blob/main/CHANGELOG.md#v1115---2021-10-14))
- ART: Crash on VL reminder for patients who got a VL order in the last 2 months
- DDE: Duplication of patients with v4 NPIDs but no corresponding DDE doc ID (these are old DDE patients)

 ## v4.12.1 - 2021-10-09

 ### Fixed

 - ART: Cohort report not picking tx_curr on Q4 reports

### v4.12.0 - 2021-10-01

### Added

- ART: Added Drug refill visit workflow
- ART: PEPFAR viral load coverage report
- ART: Regimens 14PP and 15PP to cohort report
- DDE: Endpoint for updating local patient's demographics
- Re-assigning previously voided active filing numbers
- Lab: Test measure for CrAg test
- New locations:
  - Banja Care Private Clinic (Mulanje)
  - Chikuli Private Clinic (Mulanje)
- DDE: Pushing of footprint to DDE on encounter create
- New concepts:
  - Cryotherapy (a CxCa procedure)
  - Drug refill (an ART procedure)

### Fixed

- ART: Pyridoxine not being automatically prescribed on 3HP prescriptions
- ART Stock: Resetting of current quantity on dispensation reversal
- ART Stock: Relocation of drugs at a date before their delivery date
- ART Stock: Drug relocations not saving retrospective dates
- ART: Hanging pills not being added to appointment date
- Bumped up lab to v1.1.13 - Fixes error on LIMS push of orders created through LOS
- Patient merging not appending secondary patient identifiers to primary patient (helpdesk [#3541](https://egpafemr.sdpondemand.manageengine.com/app/itdesk/ui/requests/118246000006095075/details))
- ART: Regimen distribution pulling defaulters
- ART Stock: Relocation of drugs at a date before their delivery date
- ART Stock: Drug relocations not saving retrospective dates


### Changed

- ART: VL Reminders to use 2020 MoH guidelines
- ART: TB Prev definition changed to capture 3HP for up to 6 months prior to the start of reporting period

## [v4.11.13] - 2021-08-24

### Fixed

- Lab: Bumped up to version 1.1.11 - Fixes duplicates created by v1.1.7
- ART: Added script to import staging information for old Lighthouse/MPC patients
- ART: Data cleaning tool, Missing start reason, picking all Transfer In patients (issue [#3463](https://egpafemr.sdpondemand.manageengine.com/app/itdesk/ui/requests/118246000005889001/details))
- Amount needed resetting to wrong value when dispensation is voided (github [#39](https://github.com/HISMalawi/BHT-EMR-API/issues/39))
- Lab: Bumped up to version 1.1.8 - Fixes duplication of lab orders in some facilities (helpdesk [#3470](https://egpafemr.sdpondemand.manageengine.com/app/itdesk/ui/requests/118246000005896105/details))

## [v4.11.12] - 2021-08-09

### Fixed

- Lab: Bumped up to version 1.1.7 - Fixes crash in LIMS worker on pull of orders with null specimen

## [v4.11.11] - 2021-08-07

### Fixed

- Lab: Crash on update of lab orders through the LIMS rest API configuration

## [v.4.11.10] - 2021-08-02

### Fixed

- ART: Added migration script to complete incomplete patient merges by old ART (it didn't merge orders)
- ART: TO report showing NPIDs instead of ARV numbers
- ART: TO report having TO location blank for patients with a TO on the same day as a visit

## [v4.11.9] - 2021-07-26

### Added

- ART: Inclusion of = LDL in suppressed VL results report

## [v4.11.8] - 2021-07-23

### Fixed

- Lab: Fixed processed results report duplicating results
- ART: Data cleaning tool 'prescriptions without dispensations' picking voided prescriptions
- ART: DBS VL results not being pulled in VL results report

## [v4.11.7] - 2021-07-22

### Fixed

- ART: Data cleaning tool 'encounters after death' picking voided encounters
- ART: 500 Error when merging local patients that have DDE IDs when DDE is disabled

## [v4.11.6] - 2021-07-21

### Added

- Lab: Bumped up lab to v1.1.5 - fixes failure to push orders with patients missing phone numbers

## [v4.11.5] - 2021-07-20

### Fixed

- ART: Missing transfer out to location on transfer out (outcome) report
- ART: Added check for missing dispensation observations in patients without prescriptions cleaning tool

## [v4.11.4] - 2021-07-19

### Added

- ART: script that voids invalid vitals (with values equal to NULL or zero)
- Lab: Bumped up to v1.1.3 - Adds config for selecting lims_api for sync

### Fixed

- ART: patient_current_regimen function returning multiple regimens

## [v4.11.3] - 2021-07-15

### Added

- Bumped up lab to v1.1.2 (See its [CHANGELOG](https://github.com/EGPAFMalawiHIS/his_emr_api_lab/blob/main/CHANGELOG.md) for more details)
- New sites:
  * Army Secondary school - Blantyre
  * Kavuzi Cumnoc - Nkhata-bay
- New concept: Stat

## [v4.11.2] - 2021-07-15

### Changed

- Bumped up his-emr-api-lab to v1.1.1 - This adds LIMS API integrations

## [v4.11.1] - 2021-07-07

### Fixed

- Crash on attempt to merge local patients (ie not from DDE)

### Added

- ART: Endpoint for retrieving drug doses based on patient's current weight


## [v4.11.0] - 2021-06-28

### Fixed

- ART: AZT 300 / 3TC 300 + DTG 50 being classified as Other regimen instead of 14A

### Added

- ART: Regimen 14PP
- Facility: St. Faith Health Centre (STFA) Kasungu
- Facility: St. Augustine Health Centre (STAU) Kasungu

## [v4.10.48] - 2021-06-23

### Added

- ART: Optional range parameter to high viral load report
- ART: Regimen 15PP

### Fixed

- Crash on startup in production

## [v4.10.47] - 2021-06-21

### Added

- Script to void and reassign duplicate filing numbers
- ART: Archiving candidatesw report


## [v4.10.45] - 2021-06-16

### Changed

- Bumped up lab to version 1.0.4

## [v4.10.44] - 2021-06-15

### Fixed

- ART: Incomplete visits data cleaning tool including initial staging and vitals for
       Transfer Ins as incomplete visit
- ART: Patients with closing states like Died and TO appearing in VL due report
- ART: Migrated results missing from High VL report

## [v4.10.43] - 2021-06-08

### Fixed

- ART: Regimen 17A containing 16P drug ABC 60 / 3TC 30 + RAL 400

## [v4.10.42] - 2021-06-08

### Changed

- Lab: Bumped up to v1.0.2 - Fixes crash on push of non-VL tests to LIMS

## [v4.10.41] - 2021-06-07

### Changed

- Lab: Bumped up his_emr_api_lab to version 1.0.1 - Fixes HIV Viral Load mapping between EMR and LIMS

## [v4.10.40] - 2021-06-04

### Added

- ART: Added high viral load patients report
- Lab: Added samples drawn report
- Lab: Added results added report

### Fixed

- Lab: Bumped up lab gem to version 1.0.0

## [v4.10.38] - 2021-05-21

### Added

- Lab: Lims data import from MySQL.

### Fixed

- DDE: Crash on search of patient by name and gender when DDE is enabled

## [v4.10.37] - 2021-05-12

### Fixed

- ART: Missing result date on visit summary
- ART: Missing Viral Load on visit summary when result type is non-numeric (ie text) (Fixes #2762 on EGPAF EMR helpdesk)
- ART: Lab encounters being counted as incomplete visits in dashboard visits report
- Lab: Bumped up lab to version 0.0.14 (fixes lab order label provider name)

### Added

- ART Stock: Barcodes to inventory items

## [v4.10.36] - 2021-05-07

### Fixed

- Removed duplicate HIV Viral load concepts


## [v4.10.35] - 2021-04-30

### Added

- Bumped up lab gem to version 0.0.12: Enables limiting number of LIMS migration workers

## [v4.10.34] - 2021-04-20

### Added

- Lab: Added LIMS migration and worker scripts


### [4.10.28] - 2021-04-07

### Fixed

- Lab: Updated his-emr-api-lab.gem to v0.0.1

## [4.10.27] - 2021-04-01
### Fixed

- ART: Filtered out patients with NULL drug order quantities from cohort report
## [4.10.26] - 2021-03-29

### Fixed

- ART: Lab visits being flagged as incomplete visits (EGPAF EMR Helpdesk #2376)


## [4.10.25] - 2021-03-27

### Added

- Added health centre: Kaongizi Health Centre - Nkhotakota
- ART: Revised TB Prev report
- ART Stock: Updated names of drugs to use MoH short form naming convention
- ART: Newly initiated on TB Preventive Therapy age disaggregated report
- ART: Report on drug dispensations disaggregated by pack_sizes
- ART Stock: Renamed pharmacy transaction types:
  Tins Removed => Drugs removed, New Deliveries => Drugs Added, Edited Stock => Drugs Edited
- ART Stock: Endpoint for retrieving an audit trail
- ART Stock: Separation of stock items by pack size in addition to drug id
- Global patient voiding (voids all of a patient's records)
- ART: Indicators for patients newly initiated on TB Preventive Therapy

### Fixed

- ART: Transfer out only visits from incomplete visits report (EGPAF EMR Helpdesk #2355)
- ART: External consultations appearing on missed appointments report
- 422 Error on patient merge (EGPAF Helpdesk #1947)
- Invalid (memoized) current health center value after updating current health center
- ART: Data cleaning tool, encounters after death, pulling patients that aren't dead or
  don't have encounters after death (EGPAF EMR Helpdesk #1977).

## [4.10.22] - 2021-02-12

### Fixed

- ART: External consultations appearing on defaulters list (EGPAF EMR Helpdesk #2178)

## [4.10.21] - 2021-02-10

### Fixed

- ART Stock: Race condition on parallel dispensation of same drug (eg when multiple packs are dispensed using v4.11.1 ART)

## [4.10.20] - 2021-02-08

### Fixed

- ART: Misalignment of cohort disaggregated indicators with other report indicators

## [4.10.19] - 2021-02-03

### Fixed

- ART: Appended drug strengths to visit summary (EGPAF Helpdesk #2112)
- Various query optimisations (N + 1 query fixes)
- ART: Optimised query for searching for filing numbers that qualify for archival (EGPAF EMR Helpdesk #1948)
- ART Stock: Stock Card Report Changes from zero when voiding an encounter even when the stock level was zero (EGPAF EMR Helpdesk #1989)
- ART: Fixed display of drug adherence on patient mastercard (was almost always returning nil)

## [4.10.18] - 2020-12-16

### Changed

- Added new clinics to metadata: Mehboob, FPAM, PIH Dalitso
- ART: TX-RTT Report to MER 2.5 ([#13](https://github.com/HISMalawi/BHT-EMR-API/issues/13))

## [4.10.17] - 2020-12-03

### Added

- ART: Patient drilldown to cohort disaggregated.

### Fixed

- Failure to pull drug orders by both date and program_id for patients with
  multiple treatment encounters.
- ART: Resetting of amount needed to dispensed value instead of interval
  selected by clinician on dispensation voiding.
- Leak of User.current and Location.current across threads.
- ART: Failure to dispense drugs for patients without an ART start state.

## [4.10.16] - 2020-11-10

### Fixed

- ART: Previously on treatment patients who are currently not on treatment were
  not being switched back to on treatment upon ARV dispensation.
- ART Stock: Resetting of available quantity to delivered quantity on voiding
  of any dispensations instead of just adding the dispensations back to the
  available quantity.

## [4.10.15] - 2020-10-21

### Added

- ART: Granules and Tablets disaggregation for 9P and 11P on cohort report.
- Visit report drilldown

### Fixed

- ART: Cohort report crash when cohort is run in quarters without any patients
  that have an 'On Treatment' status/outcome.

## [4.10.14] - 2020-10-16

### Added

- ART: Optimisations of slow running data cleaning tools: Missing ART reason
- ART: Client visit report

### Fixed

- Missing 'Antiretrovirals' concept set member in metadata: LPV/r Granules.
- Missing clinics in metadata: Umunthu Foundation Clinic, Kameza Macro, Chilaweni.
- ART: Undercounting of female pregnant in cohort due to patient pregnant
  observations without an answer.
- ART: Counting of patients that started treatment before the last 6 months
  in TB Prev.
- ART: Double counting of Re-initiated and Transfer ins on cohort (NOTE:
  This was more of a data integrity issue as opposed to an actual bug in
  the system. Some patients had multiple *last taken ART* observations
  with different answers that fit both Re-initiated and Transfer in
  classifications).
