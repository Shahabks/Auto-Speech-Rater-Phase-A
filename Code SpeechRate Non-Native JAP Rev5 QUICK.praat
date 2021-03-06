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
# modified 2017.05.26 by Shahab Sabahi, 
# Overview of changes: 
# + change threshold-calculator: rather than using median, use the almost maximum
#     minus 25dB. (25 dB is in line with the standard setting to detect silence
#     in the "To TextGrid (silences)" function.
#     Almost maximum (.99 quantile) is used rather than maximum to avoid using
#     irrelevant non-speech sound-bursts.
# + add silence-information to calculate articulation rate and ASD (average syllable
#     duration.
#     NB: speech rate = number of syllables / total time
#         articulation rate = number of syllables / phonation time
# + remove max number of syllable nuclei
# + refer to objects by unique identifier, not by name
# + keep track of all created intermediate objects, select these explicitly, 
#     then Remove
# + provide summary output in Info window
# + do not save TextGrid-file but leave it in Object-window for inspection
#     (if requested in startup-form)
# + allow Sound to have starting time different from zero
#      for Sound objects created with Extract (preserve times)
# + programming of checking loop for mindip adjusted
#      in the orig version, precedingtime was not modified if the peak was rejected !!
#      var precedingtime and precedingint renamed to currenttime and currentint
#
# + bug fixed concerning summing total pause, May 28th 2017
###########################################################################


# counts syllables of all sound utterances in a directory
# NB unstressed syllables are sometimes overlooked
# NB filter sounds that are quite noisy beforehand
# NB use Silence threshold (dB) = -20 (or -20?)
# NB use Minimum dip between peaks (dB) = between 2-4 (you can first try;
#                                                      For clean and filtered: 4)


form Counting Syllables in Sound Utterances
   real Silence_threshold_(dB) -20
   real Minimum_dip_between_peaks_(dB) 2
   real Minimum_pause_duration_(s) 0.3
   boolean Keep_Soundfiles_and_Textgrids yes
   sentence directory C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\INPUT/
endform

 

# shorten variables
silencedb = 'silence_threshold'
mindip = 'minimum_dip_between_peaks'
showtext = 'keep_Soundfiles_and_Textgrids'
minpause = 'minimum_pause_duration'
 
# read files
Create Strings as file list... list 'directory$'/*.wav
numberOfFiles = Get number of strings
for ifile to numberOfFiles
   select Strings list
   fileName$ = Get string... ifile
   Read from file... 'directory$'/'fileName$'

# use object ID
   soundname$ = selected$("Sound")
   soundid = selected("Sound")

   originaldur = Get total duration
   # allow non-zero starting time
   bt = Get starting time

   # Use intensity to get threshold
   To Intensity... 50 0 yes
   intid = selected("Intensity")
   start = Get time from frame number... 1
   nframes = Get number of frames
   end = Get time from frame number... 'nframes'

   # estimate noise floor
   minint = Get minimum... 0 0 Parabolic
   # estimate noise max
   maxint = Get maximum... 0 0 Parabolic
   #get .99 quantile to get maximum (without influence of non-speech sound bursts)
   max99int = Get quantile... 0 0 0.99

   # estimate Intensity threshold
   threshold = max99int + silencedb
   threshold2 = maxint - max99int
   threshold3 = silencedb - threshold2
   if threshold < minint
       threshold = minint
   endif

  # get pauses (silences) and speakingtime
   To TextGrid (silences)... threshold3 minpause 0.1 silent sounding
   textgridid = selected("TextGrid")
   silencetierid = Extract tier... 1
   silencetableid = Down to TableOfReal... sounding
   nsounding = Get number of rows
   npauses = 'nsounding'
   speakingtot = 0
   for ipause from 1 to npauses
      beginsound = Get value... 'ipause' 1
      endsound = Get value... 'ipause' 2
      speakingdur = 'endsound' - 'beginsound'
      speakingtot = 'speakingdur' + 'speakingtot'
   endfor

   select 'intid'
   Down to Matrix
   matid = selected("Matrix")
   # Convert intensity to sound
   To Sound (slice)... 1
   sndintid = selected("Sound")

   # use total duration, not end time, to find out duration of intdur
   # in order to allow nonzero starting times.
   intdur = Get total duration
   intmax = Get maximum... 0 0 Parabolic

   # estimate peak positions (all peaks)
   To PointProcess (extrema)... Left yes no Sinc70
   ppid = selected("PointProcess")

   numpeaks = Get number of points

   # fill array with time points
   for i from 1 to numpeaks
       t'i' = Get time from index... 'i'
   endfor 


   # fill array with intensity values
   select 'sndintid'
   peakcount = 0
   for i from 1 to numpeaks
       value = Get value at time... t'i' Cubic
       if value > threshold
             peakcount += 1
             int'peakcount' = value
             timepeaks'peakcount' = t'i'
       endif
   endfor


   # fill array with valid peaks: only intensity values if preceding 
   # dip in intensity is greater than mindip
   select 'intid'
   validpeakcount = 0
   currenttime = timepeaks1
   currentint = int1

   for p to peakcount-1
      following = p + 1
      followingtime = timepeaks'following'
      dip = Get minimum... 'currenttime' 'followingtime' None
      diffint = abs(currentint - dip)

      if diffint > mindip
         validpeakcount += 1
         validtime'validpeakcount' = timepeaks'p'
      endif
         currenttime = timepeaks'following'
         currentint = Get value at time... timepeaks'following' Cubic
   endfor


   # Look for only voiced parts
   select 'soundid' 
   To Pitch (ac)... 0.02 30 4 no 0.03 0.25 0.01 0.35 0.25 450
   # keep track of id of Pitch
   pitchid = selected("Pitch")

   voicedcount = 0
   for i from 1 to validpeakcount
      querytime = validtime'i'

      select 'textgridid'
      whichinterval = Get interval at time... 1 'querytime'
      whichlabel$ = Get label of interval... 1 'whichinterval'

      select 'pitchid'
      value = Get value at time... 'querytime' Hertz Linear

      if value <> undefined
         if whichlabel$ = "sounding"
             voicedcount = voicedcount + 1
             voicedpeak'voicedcount' = validtime'i'
         endif
      endif
   endfor

   
   # calculate time correction due to shift in time for Sound object versus
   # intensity object
   timecorrection = originaldur/intdur

   # Insert voiced peaks in TextGrid
   if showtext > 0
      select 'textgridid'
      Insert point tier... 1 syllables
      
      for i from 1 to voicedcount
          position = voicedpeak'i' * timecorrection
          Insert point... 1 position 'i'
      endfor
   endif

Save as text file: "C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\INPUT/'soundname$'.TextGrid"

   # clean up before next sound file is opened
    select 'intid'
    plus 'matid'
    plus 'sndintid'
    plus 'ppid'
    plus 'pitchid'
    plus 'silencetierid'
    plus 'silencetableid'

    Remove
    if showtext < 1
       select 'soundid'
       plus 'textgridid'
       Remove
    endif


# summarize results in Info window
   speakingrate = 'voicedcount'/'originaldur'
   speakingraterp = ('voicedcount'/'originaldur')*100/3.93
   articulationrate = 'voicedcount'/'speakingtot'
   articulationraterp = ('voicedcount'/'speakingtot')*100/4.64
   npause = 'npauses'-1
   asd = 'speakingtot'/'voicedcount'
   avenumberofwords = ('voicedcount'/1.74)/'speakingtot'
   avenumberofwordsrp = (('voicedcount'/1.74)/'speakingtot')*100/2.66
   nuofwrdsinchunk = (('voicedcount'/1.74)/'speakingtot')* 'speakingtot'/'npauses'
   nuofwrdsinchunkrp = ((('voicedcount'/1.74)/'speakingtot')* 'speakingtot'/'npauses')*100/9
   avepauseduratin = ('originaldur'-'speakingtot')/('npauses'-1)
   avepauseduratinrp = (('originaldur'-'speakingtot')/('npauses'-1))*100/0.75
   balance = ('voicedcount'/'originaldur')/('voicedcount'/'speakingtot')
   balancerp = (('voicedcount'/'originaldur')/('voicedcount'/'speakingtot'))*100/0.85
   nuofwrds= ('voicedcount'/1.74)
   

     
       
   if avepauseduratin<=1.27 and avepauseduratin>=1.13 
         z$="L-4 Your speech has many unnatural intonation and pronunciation" 
               elsif avepauseduratin<=1.13 and avepauseduratin>=0.89 
                     z$="L-3 It indicates that your speech has unclear stress or inappropriate intonation when you must create language"
                           elsif avepauseduratin<=0.89 and avepauseduratin>=0.69 
                                z$="L-2 It suggests that your speech has minor difficulties with intonation and stress when creating speech"
                                    elsif avepauseduratin<=0.69 and avepauseduratin>=0.48 
                                       z$="L-1 It indicates that your intonation and stress are at all times highly inteligible"
                                         else 
                                           z$= "Unnatural and unclear speech"                        
    endif
    if nuofwrdsinchunk>=4.8 and avepauseduratin>1.13 
         l$="L-1 Your use of basic and complex grammar is good"
          elsif nuofwrdsinchunk>=4.8 and avepauseduratin<=1.13 
            l$="L-2 Your speech has some grammatical mistakes when using complex grammatical structures"
              elsif nuofwrdsinchunk<4.8 and avepauseduratin<=1.13 
                 l$="L-3 Your speech has a few grammatical mistakes when using complex grammatical structures"
                   elsif nuofwrdsinchunk<=4.8 and avepauseduratin>1.13 
                     l$="L-4 You have limited grammatical knowledge"
                       else
                         l$="Detection of many inaccurate structures"
    endif 
	if avenumberofwords<=3.14 and avenumberofwords>=2.67  
           o$="L-1 Your speech reflects a good thought organization and pragmatic language appropriateness"
             elsif avenumberofwords<=2.67 and avenumberofwords>=2.55 
               o$="L-2 Your speech reflects a fair thought organization and pragmatic language appropriateness"
                  elsif avenumberofwords<=2.55 and avenumberofwords>=2.27 
                       o$="L-3 Your speech reflects problems with thought organization and is not appropriate"
                          elsif avenumberofwords<=2.27 and avenumberofwords>=1.95 
                            o$="L-4 Your speech reflects unfamiliarity with the topic in question or lack of vocabulary knowledge"
                               else 
                                o$= "Your speech reflects that your thought is not at all organized and/or not at all appropriate" 
    endif
      if speakingrate<=4.26 and speakingrate>=3.16 
           q$="L-1 It represents that you are highly confident about using language for a large diversity of topics"     
             elsif speakingrate<=3.16 and speakingrate>=3.00 
               q$="L-2 It represents that you are confident about using language but not for all range of topics"     
                 elsif speakingrate<=3.00 and speakingrate>=2.43 
                     q$="L-3 Your speech is broken and you are fairly confident about using language"     
                       elsif speakingrate<=2.43 and speakingrate>=1.55 
                         q$="L-4 Your speech is slow and you are not confident about using language"          
                           else 
                                   q$="Disfluency, Cluttering, Your speech is either slow or too fast, and inaccurate "        
    endif    
      if articulationrate<=5.46 and articulationrate>=5.05 
           w$="L-1 Your speech is coherent, it indicates that you are familiar with the topic and using language well"
             elsif articulationrate<=5.05 and articulationrate>=4.85 
               w$="L-2 Your speech is somehow coherent but you may not be familiar with the topic or not be familiar with the logical structure"
                 elsif articulationrate<=4.85 and articulationrate>=4.44 
                     w$="L-3 Your speech is incoherent, it suggests that you are not familiar with the topic and unable to use the logical structure"
                       elsif articulationrate<=4.44 and articulationrate>=3.40 
                         w$="L-4 Your speech has consistent pronunciation difficulties"
                            else 
                                   w$= "Disfluency, Cluttering" 
    endif       
       if balance<=0.90 and balance>=0.81 
          r$="L-1 It indicates that your pronunciation is at all times highly inteligible"
             elsif balance<=0.81 and balance>=0.78 
               r$="L-2 It suggests that your speech has minor difficulties with pronunciation or hesitate when creating speech"
                 elsif balance<=0.78 and balance>=0.67 
                   r$="L-3 It indicates that your speech has unclear pronunciation or inappropriate stress when you must create language"
                       elsif balance<=0.67 and balance>=0.55 
                         r$="L-4 Your speech is entirely incoherent, slow, and inaccurate"
                               else 
                                r$= "Disfluency, Inaccurate" 
    endif  

#SCORING       	 
       if avepauseduratin<=1.27 and avepauseduratin>=1.13 
          z=1
             elsif avepauseduratin<=1.13 and avepauseduratin>=0.89 
               z=2
                 elsif avepauseduratin<=0.89 and avepauseduratin>=0.69 
                   z=3
                     elsif avepauseduratin<=0.69 and avepauseduratin>=0.48 
                        z=4
                          else 
                            z=0                        
    endif
      if nuofwrdsinchunk>=4.8 and avepauseduratin>1.13
         l=4
          elsif nuofwrdsinchunk>=4.8 and avepauseduratin<=1.13 
            l=3
              elsif nuofwrdsinchunk<4.8 and avepauseduratin<=1.13 
                 l=2
                   elsif nuofwrdsinchunk<=4.8 and avepauseduratin>1.13 
                     l=1
                       else
                         l=0
    endif

    
        if avenumberofwords<=3.14 and avenumberofwords>=2.67 
           o=4
             elsif avenumberofwords<=2.67 and avenumberofwords>=2.55 
               o=3
                  elsif avenumberofwords<=2.55 and avenumberofwords>=2.27 
                       o=2
                        elsif avenumberofwords<=2.27 and avenumberofwords>=1.95 
                           o=1
                              else 
                                o=0 
    endif
      if speakingrate<=4.26 and speakingrate>=3.16 
           q=4    
             elsif speakingrate<=3.16 and speakingrate>=3.00 
               q=3     
                 elsif speakingrate<=3.00 and speakingrate>=2.43 
                     q=2    
                       elsif speakingrate<=2.43 and speakingrate>=1.55 
                         q=1         
                           else 
                                   q=0        
    endif    
      if articulationrate<=5.46 and articulationrate>=5.05 
           w=4
             elsif articulationrate<=5.05 and articulationrate>=4.85 
               w=3
                 elsif articulationrate<=4.85 and articulationrate>=4.44 
                     w=2
                       elsif articulationrate<=4.44 and articulationrate>=3.40 
                          w=1
                             else 
                                w=0 
    endif       
       if balance<=0.90 and balance>=0.81 
           r=4
             elsif balance<=0.81 and balance>=0.78 
                r=3
                 elsif balance<=0.78 and balance>=0.67 
                    r=2
                       elsif balance<=0.67 and balance>=0.55 
                        r=1
                          else 
                            r=0
    endif 

# summarize SCORE in Info window
   totalscore =(l*2+z*4+o*3+q*3+w*4+r*4)/20

totalscale= 'totalscore'*25

if totalscale>=90  
      s$="L1"
       elsif totalscale>=15 and totalscale<50   
         s$="L4"
	   elsif totalscale>=50 and totalscale<75
            s$="L3"
              elsif totalscale>=75 and totalscale<90
                s$="L2"
                   else
                     s$="Weak"   
 endif

if totalscore>=3.6  
      a=4
       elsif totalscore>=0.6 and totalscore<2   
         a=1
	   elsif totalscore>=2 and totalscore<3
            a=2
              elsif totalscore>=3 and totalscore<3.6
                a=3
                   else
                     a=0.5   
 endif

if totalscale>=90  
      s=4
       elsif totalscale>=15 and totalscale<50   
         s=1
	   elsif totalscale>=50 and totalscale<75
            s=2
              elsif totalscale>=75 and totalscale<90
                s=3
                   else
                     s=0.5   
endif

vvv=a+('totalscale'/100)

if vvv>=4
     u=4*(1-(randomInteger(1,16)/100))
	else 
	   u=vvv-(randomInteger(1,16)/100) 
endif

table = Create Table with column names: "table", 7, "Target Overall-Score Overall-Level Pronunciation Intonation Fluency Structuring Coherence Ideas-Dev "
selectObject: table
Append row
Set string value: 1, "Target", "Overall-Score"
Set string value: 2, "Target", "Overall-Level"
Set string value: 3, "Target", "Pronunciation" 
Set string value: 4, "Target", "Intonation"
Set string value: 5, "Target", "Fluency" 
Set string value: 6, "Target", "Structuring"
Set string value: 7, "Target", "Coherence"
Set string value: 8, "Target", "Ideas-Dev"

Set numeric value: 1, "Overall-Score", u
Set numeric value: 2, "Overall-Score", 0
Set numeric value: 3, "Overall-Score", 0
Set numeric value: 4, "Overall-Score", 0
Set numeric value: 5, "Overall-Score", 0
Set numeric value: 6, "Overall-Score", 0
Set numeric value: 7, "Overall-Score", 0
Set numeric value: 8, "Overall-Score", 0

Set numeric value: 1, "Overall-Level", 0
Set numeric value: 2, "Overall-Level", s
Set numeric value: 3, "Overall-Level", 0
Set numeric value: 4, "Overall-Level", 0
Set numeric value: 5, "Overall-Level", 0
Set numeric value: 6, "Overall-Level", 0
Set numeric value: 7, "Overall-Level", 0
Set numeric value: 8, "Overall-Level", 0

Set numeric value: 1, "Pronunciation", 0
Set numeric value: 2, "Pronunciation", 0
Set numeric value: 3, "Pronunciation", (r+0.05-r*randomInteger(1,10)/100)
Set numeric value: 4, "Pronunciation", 0
Set numeric value: 5, "Pronunciation", 0
Set numeric value: 6, "Pronunciation", 0
Set numeric value: 7, "Pronunciation", 0
Set numeric value: 8, "Pronunciation", 0

Set numeric value: 1, "Intonation", 0
Set numeric value: 2, "Intonation", 0
Set numeric value: 3, "Intonation", 0
Set numeric value: 4, "Intonation", (z+0.05-z*randomInteger(1,10)/100)
Set numeric value: 5, "Intonation", 0
Set numeric value: 6, "Intonation", 0
Set numeric value: 7, "Intonation", 0
Set numeric value: 8, "Intonation", 0

Set numeric value: 1, "Fluency", 0
Set numeric value: 2, "Fluency", 0
Set numeric value: 3, "Fluency", 0
Set numeric value: 4, "Fluency", 0
Set numeric value: 5, "Fluency", (q+0.05-q*randomInteger(1,10)/100)
Set numeric value: 6, "Fluency", 0
Set numeric value: 7, "Fluency", 0
Set numeric value: 8, "Fluency", 0

Set numeric value: 1, "Structuring", 0
Set numeric value: 2, "Structuring", 0
Set numeric value: 3, "Structuring", 0
Set numeric value: 4, "Structuring", 0
Set numeric value: 5, "Structuring", 0
Set numeric value: 6, "Structuring", (l+0.05-l*randomInteger(1,10)/100)
Set numeric value: 7, "Structuring", 0
Set numeric value: 8, "Structuring", 0

Set numeric value: 1, "Coherence", 0
Set numeric value: 2, "Coherence", 0
Set numeric value: 3, "Coherence", 0
Set numeric value: 4, "Coherence", 0
Set numeric value: 5, "Coherence", 0
Set numeric value: 6, "Coherence", 0
Set numeric value: 7, "Coherence", (o+0.05-o*randomInteger(1,10)/100)
Set numeric value: 8, "Coherence", 0

Set numeric value: 1, "Ideas-Dev", 0
Set numeric value: 2, "Ideas-Dev", 0
Set numeric value: 3, "Ideas-Dev", 0
Set numeric value: 4, "Ideas-Dev", 0
Set numeric value: 5, "Ideas-Dev", 0
Set numeric value: 6, "Ideas-Dev", 0
Set numeric value: 7, "Ideas-Dev", 0
Set numeric value: 8, "Ideas-Dev", (w+0.05-w*randomInteger(1,10)/100)



Bar plot where: "Overall-Score Overall-Level Pronunciation Intonation Fluency Structuring Coherence Ideas-Dev ",0,4, "Target", 1, 1, 0, "Red Blue Black Black Black Black Black Black", 15.0, "yes", "1"
Marks left every: 0.444, 1, 0.5, 0.5, 0
Text left: 1, "SCORE       Scale ONLY for RED bar"
Text right: 1, "LEVEL      ONLY for BLACK and BLUE bars"
Text top: 2, "MYSOL School of Global Communication"
# Add lines for band levels and standard deviation
	Black
	One mark left... 0.5 no no no
	One mark right... 0.5 no yes no "L4" 
	One mark left... 1 no yes no
	One mark right... 1 no yes no 
	Line width: 2
	Draw line: 0, 1, 1, 1 
	Black
	Line width: 1
	One mark left... 1.5 no no no
	One mark right... 1.5 no yes no "L3"
	One mark left... 2 no yes no
	One mark right... 2 no yes no 
	Line width: 2
	Draw line: 0, 2, 1, 2
	Black
	Line width: 1
	One mark left... 2.5 no no no
	One mark right... 2.5 no yes no "L2"
	One mark left... 3 no yes no
	One mark right... 3 no yes no 
	Line width: 2
	Draw line: 0, 3, 1, 3
	Black
	Line width: 1
	One mark left... 3.5 no no no
	One mark right... 3.5 no yes no "L1"
	One mark left... 4 no no no
	One mark right... 4 no yes no 
	Line width: 2
	Draw line: 0, 4, 1, 4 
	Green
	Line width: 5
	Dashed line
	One mark top... 0.12 no no no Overall SCORE
	One mark top... 0.67 no no no Proficiency LEVELS
	Draw line: 0.25, 0, 0.25, 4
	
	Save as 300-dpi PNG file... C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\RESULTS/'soundname$'.jpg   

Erase all

         writeFileLine: "C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\RESULTS/'soundname$'.doc", newline$
	 ... ,"PROFICIENCY LEVEL INDICES DEFINITIONS (Above, the 1st chart)", newline$
	 ... ,"*******************************************", newline$
	 ... ,"At Level 1 speakers typically can create connected, sustained discourse", newline$
	 ... ,"   appropriate to the typical workplace. When they express opinions or ", newline$
	 ... ,"   respond to complicated requests, their speech is highly intelligible.", newline$
	 ... ,"   Their use of basic and complex grammar is good, and their use of ", newline$
	 ... ,"   Vocabulary is accurate and precise. Speakers at Level 1 can also", newline$
	 ... ,"   use spoken language to answer questions and give basic information", newline$
         ... ,"   Their pronunciation, intonation and stress are at all times highly", newline$
	 ... ,"   intelligible", newline$
 	 ... ,"At Level 2 speakers typically can create connected, sustained discourse", newline$
 	 ... ,"   appropriate to the typical workplace. They can express opinions and ", newline$
	 ... ,"   respond to complicated requests effectively. In extended responses, ", newline$
	 ... ,"   some of the following weaknesses may sometimes occur,but they do not", newline$
	 ... ,"   interfere with the message: minor difficulties with pronunciation, ", newline$
	 ... ,"   intonation or hesitation when creating language,some errors when using", newline$  
	 ... ,"   complex grammatical structures, some imprecise vocabulary.Speakers", newline$
	 ... ,"   at Level 2 can also use spoken language to give basic information.", newline$  
	 ... ,"At level 3 speakers are typically able to create a relevant response when", newline$
	 ... ,"   asked to express an opinion or respond to a complicated request. ", newline$
	 ... ,"   However, at least part of the time, the reasons for or explanations", newline$
	 ... ,"   of the opinion are unclear to a listener. This may be because of ", newline$
	 ... ,"   the following:unclear pronunciation or inappropriate intonation or", newline$
	 ... ,"   stress when the speaker must create language, mistakes in grammar", newline$
	 ... ,"   , a limited range of vocabulary. Most of the time, speakers at", newline$
	 ... ,"   Level 3 can answer questions and give basic information. However", newline$
	 ... ,"   ,sometimes their responses are difficult to understand or interpret.", newline$
	 ... ,"At level 4 speakers have typically limited success at expressing an ", newline$
	 ... ,"   opinion or responding to a complicated request. Responses include ", newline$
	 ... ,"   problems such as: language that is inaccurate, vague or repetitive", newline$
	 ... ,"   , minimal or no awareness of audience, long pauses and frequent ", newline$
	 ... ,"   hesitations, limited expression of ideas and connections between ", newline$ 
	 ... ,"   ideas, a limited range of vocabulary. Most of the time, speakers", newline$
	 ... ,"   at Level 4 can answer questions and give basic information. However,", newline$
	 ... ,"   sometimes their responses are difficult to understand or interpret.", newline$
	 ... ,"   Speakers at this level when creating language, their pronunciation,", newline$
	 ... ,"   intonation and stress may be inconsistent.", newline$	 
	 ... ,"Below level 4 speakers are typically unsuccessful when attempting to ", newline$ 
	 ... ,"   explain an opinion or respond to a complicated request. The response", newline$
	 ... ,"   may be limited to a single sentence or part of a sentence. ", newline$
	 ... ,"   Other problems may include: severely limited language use, minimal ", newline$
	 ... ,"   or no awareness of audience, consistent pronunciation, stress and ", newline$
	 ... ,"   intonation difficulties, long pauses and frequent hesitations,", newline$ 
	 ... ,"   severely limited vocabulary. Most of the time, speakers below Level 4 ", newline$
	 ... ,"   cannot answer questions or give basic information. When speaking, they", newline$ 
	 ... ,"   are creating language, with pronunciation problems, intonation and ", newline$ 
	 ... ,"   stress difficulties.", newline$
	 ... ,"*************************************************************************", newline$
	 ... ,"*************************************************************************", newline$
	 ... ,"FILE NAME", tab$, tab$, tab$, soundname$, newline$
         ... ,"Number of words", tab$, tab$, 'nuofwrds:0', newline$   
      	 ... ,"Number of pauses", tab$, tab$, 'npause', newline$ 
   	 ... ,"Duration (s)", tab$, tab$, tab$,'originaldur:2', newline$
   	 ... ,"Phonation time (s)", tab$, tab$,'speakingtot:2', newline$
   	 ... ,"*************************************************************************", newline$
   	 ... ,"*************************************************************************", newline$
   	 ... ,"Proficiency in structuring*", newline$										
   	 ... , l$, newline$												  
   	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"Word stress Proficiency", newline$									
   	 ... , z$, newline$	  
   	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"Comprehensibility and coherence proficiency**", newline$			
   	 ... , o$, newline$					
  	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"Conversational proficiency****", newline$					
   	 ... , q$, newline$				
  	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"Articulation proficiency****", newline$							 
   	 ... , w$, newline$				
   	 ... ,"------------------------------------------------------------------------", newline$ 
   	 ... ,"Discussion proficiency", newline$								
   	 ... , r$, newline$
   	 ... ,"************************************************************************", newline$
   	 ... ,"Overall Band Level ---------------------------------------------------",s$, newline$
   	 ... ,"------------------------------------------------------------------------", newline$
	 ... ,"------------------------------------------------------------------------", newline$
	 ... ,"Score 1 to 2.5 [IELTS below 4,TOEFL iBT below12]", newline$
	 ... ,"Score 2.5 to 5.5 [IELTS 4-5,TOEFL iBT 12-17]", newline$
	 ... ,"Score 5.5 to 7 [IELTS 5.5-6,TOEFL iBT 18-23]", newline$
	 ... ,"Score 7 to 8 [IELTS 6.5-7.5,TOEFL iBT 24-27]", newline$
	 ... ,"Score 8 to 9 [IELTS 8-9,TOEFL iBT 28-30]", newline$
	 ... ,"* An indicator for grammar and vocab use, "   
   	 ... ,"** An indicator for Ideas development, "
   	 ... ,"*** The indicator shows ability to conduct daily conversations, "
   	 ... ,"**** The indicator reflects logical structure of speech."

endfor

