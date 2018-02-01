**Overview**
---
This repository contains a set of matlab scripts to detect threshold crossings in extracellular voltage data that has been continuously acquired using an [open ephys system](http://www.open-ephys.org/) in their .continuous format to the .nev format. This code is based on a similar function, plx2nev developed by [Matt Smith's lab](http://www.smithlab.net) at the University of Pittsburgh. To do so it executes the following steps.

1. Import data
2. Filter the data according to user specifications
3. Calculate threshold crossings, and associated waveforms
4. Write waveforms and threshold-crossing times to a .nev format

The resulting file can be read by multiple commercial and open-source spike sorting softwares. Below are some I have tested
* [Offline Sorter](http://www.plexon.com/products/offline-sorter) by Plexon
* [Spike2](http://ced.co.uk/products/spkovin) by Cambridge Electronic Design Limited
* [Spikesort](http://www.smithlab.net/spikesort.html) from Matt Smith's lab

I would appreciate help in testing the code. A word of warning, it will run very slowly with extracellular recordings from recording probes with lots of contacts. Data it is used for involve recordings taken from multilaminar probes with 32 contacts. It could probably work reasonably well up to 128 channels.

**Requirements**
---
To run this code you need the following
1. [Matlab](https://www.mathworks.com/products/matlab.html)
2. [Matlab's signal processing toolbox](https://www.mathworks.com/products/signal.html)
3. [Open ephys analysis tools](https://github.com/open-ephys/analysis-tools)

**To run**
---
Running the code is relatively simple, add the scripts and the required open ephys analysis tools scripts to your path and execute main_script.m. 

**A note on operating systems**
This should work across most operating systems. It was written and tested using Matlab 2016b running in Mac OS X 10.11.6. It was also tested on a computer running Windows 10. If you have a problem post to issues above and I will see if I can help.


**License**
---
The code is provided for free via the GNU General Public License. See license file in this repository for further details.
