# oephys2nev
This repository contains scripts that are used to convert extracellular voltage data that has been continuously acquired using an [open ephys system](http://www.open-ephys.org/) to the .nev format. This code is based on a similar function, plx2nev developed by [Matt Smith](www.smithlab.net). To do so it executes the following steps.

1. Import data
2. Filter data according to user specifications
3. Calculate threshold crossings, and associated waveforms
4. Write waveforms and threshold-crossing times to a .nev format

The resulting file can be read by multiple commercial and open-source spike sorting softwares. Below are some I have tested
* [Offline Sorter](http://www.plexon.com/products/offline-sorter) by Plexon
* [Spike2](http://ced.co.uk/products/spkovin) by Cambridge Electronic Design Limited
* [Spikesort](http://www.smithlab.net/spikesort.html) from Matt Smith's lab 

I would appreciate help in testing the code. A word of warning, it will run very slowly with extracellular recordings from recording probes with lots of contacts. Data I use it for involve recordings taken from multilaminar probes with 32 contacts. It could probably work reasonably well up to 128 channels. Optimizing it to scale upward is a future goal. 
