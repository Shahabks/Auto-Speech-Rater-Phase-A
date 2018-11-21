###########################################################################
#                                                                         #
#  Praat Script Spoken Communication Proficiency Test                     #
#  Copyright (C) 2017  Shahab Sabahi                                      #
#                                                                         #
#    This program is a Mysol software intellectual property:              # 
#    you can redistribute it and/or modify it under the terms             #
#    of the Mysol Permision.                                              #
#                                                                         #
#    This program is distributed in the hope that it will be useful,      #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                 #
#                                                                         #
#                                                                         #
###########################################################################
#
# modified 2017.06.02 by Shahab Sabahi, 
# This script calculates a Pitch object from a Sound object,
# displays basic F0 statistics, draws a histogram according to the distribution 
# of the calculated pitch points, and saves all the original pitch values to a plain text file.
#
# Exactly one Sound object must be selected in the object window.

form Draw F0 histogram from Sound object
   comment Give the F0 analysis parameters:
	positive Minimum_pitch_(Hz) 80
	positive Maximum_pitch_(Hz) 400
	positive Time_step_(s) 0.01
   comment Save F0 point data to a text file in the directory:
	text directory 
	comment (Empty directory = the same directory where this script file is.) 
   comment Number of "bars" in the histogram:
	integer Number_of_bins 1000
	choice Pitch_scale_for_drawing 1
		button Hertz
		button mel
		button semitones re 100 Hz
		button ERB
endform

Erase all

# read files
Create Strings as file list... list C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\INPUT/*.wav
numberOfFiles = Get number of strings
for ifile to numberOfFiles
   select Strings list
   fileName$ = Get string... ifile
   Read from file... C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\INPUT/'fileName$'

# use object ID
   soundname$ = selected$("Sound")
   soundid = selected("Sound")
   filename$ = "f0points'soundname$'.txt"

# Calculate F0 values
To Pitch... time_step minimum_pitch maximum_pitch
numberOfFrames = Get number of frames

# Loop through all frames in the Pitch object:
select Pitch 'soundname$'
unit$ = "Hertz"
min_Hz = Get minimum... 0 0 Hertz Parabolic
min$ = "'min_Hz'"
max_Hz = Get maximum... 0 0 Hertz Parabolic
max$ = "'max_Hz'"
mean_Hz = Get mean... 0 0 Hertz
mean$ = "'mean_Hz'"
stdev_Hz = Get standard deviation... 0 0 Hertz
stdev$ = "'stdev_Hz'"
median_Hz = Get quantile... 0 0 0.50 Hertz
median$ = "'median_Hz'"
quantile25_Hz = Get quantile... 0 0 0.25 Hertz
quantile25$ = "'quantile25_Hz'"
quantile75_Hz = Get quantile... 0 0 0.75 Hertz
quantile75$ = "'quantile75_Hz'"
if pitch_scale_for_drawing > 1
	unit$ = unit$ + "	'pitch_scale_for_drawing$'"
	min = Get minimum... 0 0 "'pitch_scale_for_drawing$'" Parabolic
	min$ = min$ + "	'min'"
	max = Get maximum... 0 0 "'pitch_scale_for_drawing$'" Parabolic
	max$ = max$ + "	'max'"
	mean = Get mean... 0 0 'pitch_scale_for_drawing$'
	mean$ = mean$ + "	'mean'"
	if pitch_scale_for_drawing <> 3 
		pitch_scale_short$ = pitch_scale_for_drawing$
	else
		pitch_scale_short$ = "semitones"
	endif
	stdev = Get standard deviation... 0 0 'pitch_scale_short$'
	stdev$ = stdev$ + "	'stdev'"
	median = Get quantile... 0 0 0.50 'pitch_scale_for_drawing$'
	median$ = median$ + "	'median'"
	quantile25 = Get quantile... 0 0 0.25 'pitch_scale_for_drawing$'
	quantile25$ = quantile25$ + "	'quantile25'"
	quantile75 = Get quantile... 0 0 0.75 'pitch_scale_for_drawing$'
	quantile75$ = quantile75$ + "	'quantile75'"
endif
	j='stdev$'
	Red
	if mean_Hz<=126.2 and mean_Hz>=116.9
	  w$="L1...... You delivered a clear, articulated speech"
	   elsif mean_Hz<=116.9 and mean_Hz>=113.8
	       w$="L2...... You delivered a fairly clear but partialy articulated speech"
		elsif mean_Hz<=113.8 and mean_Hz>=110.7
		  w$="L3...... You delivered a partialy clear and fully unarticulated speech"
		    elsif mean_Hz<=110.7 and mean_Hz>=107.6
			w$="L4...... You delivered an unclear and unartculated speech"
			  else
				w$="totally unclear speech"
endif   	
	Red
	s=j*j/(3.4*3.4)

# Print the statistics to the Info window:
echo F0 statistics from 'soundname$'
printline		'unit$'
printline Min		'min$'
printline Max		'max$'
printline Median	'median$'
printline 25% quantile	'quantile25$'
printline 75% quantile	'quantile75$'
printline Mean		'mean$'
printline Stdev		'stdev$'
Red
printline Level scale  107.6<<<L4>>>110.7<<<L3>>>113.8<<<L2>>>116.9<<<L1>>>126.2
printline Your level	'w$'
printline Factor delta	's'	
Blue
printline Selected options
printline Minimum pitch: 'minimum_pitch' Hz
printline Maximum pitch: 'maximum_pitch' Hz
printline Time step: 'time_step' s
printline Number of bins in the histogram: 'number_of_bins'

# Collect and save the pitch values from the individual frames to the text file:
for iframe to numberOfFrames
	timepoint = Get time from frame... iframe
	f0 = Get value in frame... iframe 'pitch_scale_for_drawing$'
	if f0 <> undefined
		fileappend 'filename$' 'f0''newline$'
	endif
endfor

# Convert the original minimum and maximum parameters in order to define the x scale of the 
# picture, if required:
if pitch_scale_for_drawing = 2
	minimum_pitch = hertzToMel(minimum_pitch)
	maximum_pitch = hertzToMel(maximum_pitch)
elsif pitch_scale_for_drawing = 3
	minimum_pitch = hertzToSemitones(minimum_pitch)
	maximum_pitch = hertzToSemitones(maximum_pitch)
elsif pitch_scale_for_drawing = 4
	minimum_pitch = hertzToErb(minimum_pitch)
	maximum_pitch = hertzToErb(maximum_pitch)
endif

# Read the saved pitch points as a Matrix object:
Read Matrix from raw text file... 'filename$'

# Draw the Histogram
Pink
Line width: 1
Dashed line
Draw distribution... 0 0 0 0 minimum_pitch maximum_pitch number_of_bins 0 0 yes

Red
Font size: 12
Text... 250 centre 60 half "Intonation Index"
Font size: 7
Text... 250 centre 54 half "Considered a good intonation when --Your range-- falls within the male or female specification limit"   
Blue
Font size: 8
Text... 215 centre 37 half "Norm female range"
Green
Text... 125 centre 37 half "Norm male range"
Red
One mark bottom... 'quantile25$'+'quantile25$'/8 no no no "Your range"

Red
Line width: 3
Solid line
Draw line... 'quantile25$' 0 'quantile25$' 10
Draw line... 'quantile75$' 0 'quantile75$' 10
One mark bottom... 'quantile25$' no yes no  
One mark bottom... 'quantile75$' no yes no 
Green
Line width: 4
Draw line... 101 0 101 30 
Draw line... 142 0 142 30 
Blue
Line width: 4
Draw line... 182 0 182 30 
Draw line... 239 0 239 30


printline
printline The defined pitch values from all frames were saved to the file
printline 'filename$'.

Save as 300-dpi PNG file... C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\RESULTS/'soundname$'intonation.jpg  

Erase all

endfor