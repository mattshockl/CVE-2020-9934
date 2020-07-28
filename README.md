# CVE-2020-9934

This Proof of Concept is a simple Swift program that will give itself and Terminal every kTCCService entitlement (pulled from tccd) and then do four things:
* Create a file named "<<<\<BYPASS>>>>" in the TCC-protected directory
* Read the data from said file from within the TCC-protected directory
* List all files in the TCC-directory (including "<<<\<BYPASS>>>>")
* Remove the file from the TCC-protected directory

Usage:
`./bypasstc <tcc-protected directory>`

See the [full writeup on Medium](https://medium.com/@mattshockl/cve-2020-9934-bypassing-the-os-x-transparency-consent-and-control-tcc-framework-for-4e14806f1de8)
