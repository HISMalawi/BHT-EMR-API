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

### Fixed

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
