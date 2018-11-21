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

Save as text file: "'directory$'/'soundname$'.TextGrid"

   # clean up before next sound file is opened
    select 'intid'
    plus 'matid'
    plus 'sndintid'
    plus 'ppid'
    plus 'pitchid'
    plus 'silencetierid'
    plus 'silencetableid'

	Read from file... 'directory$'/'fileName$'
	soundname$ = selected$ ("Sound")
	To Formant (burg)... 0 5 5500 0.025 50
	Read from file... 'directory$'/'soundname$'.TextGrid
	int=Get number of intervals... 2


# We then calculate F1, F2 and F3

fff= 0
eee= 0
inside= 0
outside= 0
for k from 2 to 'int'
	select TextGrid 'soundname$'
	label$ = Get label of interval... 2 'k'
	if label$ <> ""

	# calculates the onset and offset
 		vowel_onset = Get starting point... 2 'k'
  		vowel_offset = Get end point... 2 'k'

		select Formant 'soundname$'
		f_one = Get mean... 1 vowel_onset vowel_offset Hertz
		f_two = Get mean... 2 vowel_onset vowel_offset Hertz
		f_three = Get mean... 3 vowel_onset vowel_offset Hertz
		
		ff = 'f_two'/'f_one'
		lnf1 = 'f_one'
		lnf2f1 = ('f_two'/'f_one')
		uplim =(-0.012*'lnf1')+13.17
		lowlim =(-0.0148*'lnf1')+8.18
	
		f1uplim =(lnf2f1-13.17)/-0.012
		f1lowlim =(lnf2f1-8.18)/-0.0148
	
	
	
	if lnf1>='f1lowlim' and lnf1<='f1uplim' 
	    inside = 'inside'+1
		else
		   outside = 'outside'+1
	endif
		fff = 'fff'+'f1uplim'
		eee = 'eee'+'f1lowlim'
ffff = 'fff'/'int'
eeee = 'eee'/'int'
pron =('inside'*100)/('inside'+'outside')
prom =('outside'*100)/('inside'+'outside')
prob1 = invBinomialP ('pron'/100, 'inside', 'inside'+'outside')
prob = 'prob1:2'
		
	endif
endfor

lnf0 = (ln(f_one)-5.65)/0.31
f00 = exp (lnf0)

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
   f1norm = -0.0118*'pron'*'pron'+0.5072*'pron'+394.34
   inpro = ('nuofwrds'*60/'originaldur')
   polish = 'originaldur'/2



  if f00<90 or f00>255
         z$="イントネーションで、不自然な部分が多く見受けられます。書き写した文章を読んでいるようなフラットな話し方です。文章の中で、イントネーションやアクセントに気を付けながら話す必要があります。　例えば、GO TO BED の場合は BED が強調され、TOはほとんど聞こえないぐらい弱く発音します。BANANAの場合は、真ん中のNAが強調され第１、３音節のBAとNAは弱くなります。１つ１つの音を強く発音するのではなく、音を繋ぎ合わせたり、特定の言葉に重点を置く場合にその言葉を強調したりします。例えば、I AMでは(I)が強調されAMは弱く、I DO NOT KNOWは(T)の音は発音しません。また、WHITE BAG の(T)は音が (P)に変わり発音されます."     
               elsif f00<97 or f00>245  
                     z$="自らの表現で話す事が出来ています。イントネーションが不適切な部分が見受けられます。例えば、GO TO BED の場合は BED が強調され、TOはほとんど聞こえないぐらい弱く発音します。 BANANAの場合は、真ん中のNAが強調され第１、３音節のBAとNAは弱くなります。１つ１つの音を強く発音するのではなく、音を繋ぎ合わせたり、特定の言葉に重点を置く場合にその言葉を強調したりします。例えば, I AMでは(I)が強調されAMは弱く、I DO NOT KNOWは(T)の音は発音しません。また、WHITE BAG の(T)は音が (P)に変わり発音されます " 
                           elsif f00<115 or f00>245 
                                       z$="正確で、非常にわかりやすいイントネーションやアクセントです。 １つ１つの音を強く発音するのではなく、音を繋ぎ合わせたり、特定の言葉に重点を置く場合にその言葉を強調したりします。例えば, I AMでは(I)が強調されAMは弱く、I DO NOT KNOWは(T)の音は発音しません。また、WHITE BAG の(T)は音が (P)に変わり発音されます " 
						elsif f00<=245 and f00>=115 
						z$="非常に分かりやすいイントネーションやアクセントで、まるでネイティブスピーカーのようです"
						else 
                           z$= "単調または、不明瞭な音"                        
    endif
    if nuofwrdsinchunk>=6.24 and avepauseduratin<=1.0 
         l$="一貫して正しい文法で話す事が出来ていて素晴らしいです。" 
		elsif nuofwrdsinchunk>=6.24 and avepauseduratin>1.0 
            l$="正しい文法で話せています。複雑な文法でも間違い無く話す事が出来ています。慣用表現やコロケーション（よく使われる組み合わせ、自然な語の繋がりの事。）も正しく使用できています。"
          elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin<=1.15 
            l$="正しい文法で話せています。複雑な文を話す場合もほぼ間違いは見受けられませんが少しの間違いがあります。関係説節、仮定法、比較、最上級形容詞を使った文を使用する必要があります。"
		elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin>1.15 
             l$="正しい文法で話せています。しかし、複雑な文を話す時 、文法上の間違いが見受けられます。関係詞節、仮定法、比較、最上級形容詞を使った文を使用する必要があります。（主節(main)と１つ以上の副詞節(adv)と仮定法を使った複雑な文章、副詞節は通常主節の後にきます。例えば; her brother got married (main) when she was very young (adv.) or although (conj：接続詞) a few snakes are dangerous (adv) most of them are quite harmless (main)等）" 
              elsif nuofwrdsinchunk<4.4 and avepauseduratin<=1.15 
                   l$="複雑な作りの文を話す時にいくつかの文法上の間違いが見受けられます。 複雑な文ばかりではなく、正確で単純な文を使ったほうが良いでしょう。関係詞節、仮定法、比較、最上級形容詞を使った文を使用する必要があります。（主節(main)と１つ以上の副詞節(adv)と仮定法を使った複雑な文章、副詞節は通常主節の後にきます。例えば; her brother got married (main) when she was very young (adv.) or although (conj：接続詞) a few snakes are dangerous (adv) most of them are quite harmless (main)等）" 
                   elsif nuofwrdsinchunk<=4.4 and avepauseduratin>1.15 
                       l$="文法に多くの誤りが見受けられます。正確で単純な文（１節）と複雑な文を使用する必要があります。関係詞節、仮定法、比較、最上級形容詞を使った文を使用する必要があります。（主節(main)と１つ以上の副詞節(adv)と仮定法を使った複雑な文章、副詞節は通常主節の後にきます。例えば her brother got married (main) when she was very young (adv.) or although (conj：接続詞) a few snakes are dangerous (adv) most of them are quite harmless (main)等）" 
                       else
                         l$="不明瞭な音"
    endif 
	if balance>=0.69 and avenumberofwords>=2.60  
           o$="あなたの会話は優れており、実用的に正しく話す事が出来ています。質問をする際も文脈が正しく単語の使いかたもとても上手く使われています。複雑な内容の自分の意見でも自信を持って伝える事が出来るでしょう。 "
		elsif balance>=0.60 and avenumberofwords>=2.43  
           o$="あなたの会話は分かりやすい文脈で会話が出来ています。質問をする場合にも相手に伝わるよう正しい単語使いが出来ています。また、ビジネスの場での議論でも対等に会話する事が出来るでしょう。 "
             elsif balance>=0.5 and avenumberofwords>=2.25 
               o$="あなたの会話は、文脈をたどって会話する事が出来ています。十分な専門的な単語の知識もあり、実用的な言語の仕様も正しく出来ています。少し話題についていく事が出来ない場合があるようなので、コミュニケーション力を効果的に使用する必要があります。 "
                  elsif balance>=0.5 and avenumberofwords>=2.07 
                       o$="あなたの会話には、専門的な単語の知識に限りがあります。議論をする場合、会話についていく事が難しいようです。話題に自信が無い場合、語彙力の幅を広げ、コミュニケーション能力を効果的に活用する必要があります。 "
                          elsif balance>=0.5 and avenumberofwords>=1.95 
                            o$="あなたの会話には、語彙力の乏しさやコミュニケーション方法、話すパターンに不慣れな事が見受けられます。"
                               else 
                                o$= "不明瞭な音" 
    endif
     if speakingrate<=4.26 and speakingrate>=3.16 
           q$="どんな話題の場合でも自信を持って話す事が出来ています。簡単に、また流暢に自分のアイディアを話し表現する事が出来ます。少し難しい話題の場合に間違う可能性があるかもしれません。"
		elsif speakingrate<=3.16 and speakingrate>=2.54 
           q$="全体的に自信をもって会話する事が出来ています。流暢に自分のアイディアを話す事が出来ますが、少し正確に伝えようとし、会話が途切れる場面が見受けられます。また、複雑な難しい文章を話す時に間違う事が予測されます。"    
             elsif speakingrate<=2.54 and speakingrate>=1.91 
               q$="会話の幅を広げ話す事が出来ますが、良く話す内容に限られております。自分のアイディアを話す時に表現方法にためらいがあるので会話が途切れてしまう事が多くあります。 "     
                 elsif speakingrate<=1.91 and speakingrate>=1.28 
                     q$="全体的に分かりやすいですが、発音やイントネーションに誤りがある、もしくは/さらに表現や語彙の使用に自信がなく話す事がスローになっている様に見受けられます。その為、会話が途切れてしまう事が多くあります。"     
                       elsif speakingrate<=1.28 and speakingrate>=1.0 
                         q$="短い文章のみで話しているので、会話になっていない。話す事に自信が無いように見受けられます。また表現や語彙力、文法もしくは/さらに発音やイントネーション力が不足しています。また、自分のアイディアを話す事へのためらいが感じられます。"          
                           else 
                             q$="流暢さが無く、まとまりのない会話になっています。一貫性が無く話すスピードが速すぎるもしくは遅すぎます。"         
    endif    
      if balance>=0.69 and articulationrate>=4.54 
           w$="自分の意見を明確に、また説得力のある状態で話す事が出来ています。話すスピードも安定しており、様々な会話のトピックに合わせ、必要な単語や慣用的な表現が正しく出来ています。また話しているトピックについて詳しいように感じられます。"
		elsif balance>=0.60 and articulationrate>=4.22 
           w$="正しく自分の考えをまとめ、伝える事が出来ています。議論を交わす時相手にも伝わりやすく話せています。会話のトピックにより必要な単語を選び会話する事が出来ています。"
             elsif balance>=0.50 and articulationrate>=3.91 
               w$="考えを上手く表現する事が難しいようです。何を伝えたいのか理解する事が時々難しい状態です。あなたの考えを表現する時に正しい語彙の知識が不十分です。もしくは/さらに、英語でのコミュニケーションに不慣れな為考えが浮かばないようです。もしくは/さらに、議論を交わす際に上手く相手に考えを伝える事が難しいでしょう。"
                 elsif balance>=0.5 and articulationrate>=3.59 
                     w$="上手く表現する事が難しいようです。何を伝えたいのか理解する事が時々出来ません。話す事に慣れておらず、考えをまとめる事が難しいように見受けられます。また、自分の考えを順序立てて話す事が難しく、文法も不十分です。"
                       elsif balance>=0.5 and articulationrate>=3.10 
                         w$="語彙力と英文の理解力が乏しく、話す事に慣れていない状態です。"
                            else 
                               w$= "不明瞭な音"  
    endif 
	
	if originaldur>=60 and speakingtot>=polish and f1norm<=395 and eeee<=395
		warning0$ = "警告はありません。"
		else
		warning0$ = "警告"
     endif  
	 if originaldur<60 
		warning1$ = "録音音声が60秒未満の為。 音声評価の正確さに影響を与える可能性があります。"  
			else 
			warning1$ = " " 
	endif

	 if speakingtot<polish 
		 warning2$ = "会話が長い間途切れる事が多い為、音声評価の正確さに影響を与える可能性があります。"  
			else 
			warning2$ = " "	
	endif
	if f1norm>395 or eeee>395
		warning3$ = "オーディオシステムに問題があるか、録音された声がはっきりしない、もしくは発音が不明瞭な部分が多い為、音声評価の正確さに影響を与える可能性があります。" 
			else
				warning3$ = " "
	endif
	   
if inpro>=119 and ('f1norm'*1.1)>=f1lowlim 
	r$ = "ネイティブスピーカーレベルの発音" 
		elsif inpro>=119 and ('f1norm'*1.1)<f1lowlim 
			 r$ = "ネイティブスピーカーレベルに近い発音"  
				elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)>=f1lowlim 
					r$ = "ほぼ全ての発音が正しく出来ています。"  
						elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)<f1lowlim 
							r$ = "あなたの発音は基本的に正しいですが、適正ではない部分もあります。単語の発音の強弱のつけ方に気を付ける必要があります。例えば、BANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。"  
								elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)>=f1lowlim 
									r$ = "全体的に発音の間違いが目立ちます。二重母音になる単語の発音に注意が必要です。例えば、dayやhereが二重母音の単語になります。"  
									elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)<f1lowlim 
									r$ = "全体的に発音に間違いが多く見受けられます。短母音や二重母音（例day,here）や子音の有声音、無声音の発音に注意し話す必要があります。また、単語の発音の強弱のつけ方に気を付ける必要があります。例えばBANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。また、文章の中で強調される単語と、弱く発音される単語があります。例えば、GO TO BEDではGOとBEDは強く発音され、TOはほとんど聞こえないぐらいの弱さで発音されます。"
								elsif inpro<80 and inpro>=70 and ('f1norm'*1.1)>=f1lowlim 
								r$ = "発音が少し難しい部分や、躊躇しているような雰囲気が見受けられます。短母音や二重母音（例day,here）や子音の有声音、無声音の発音に注意し話す必要があります。また、単語の発音の強弱のつけ方に気を付ける必要があります。例えばBANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。また、文章の中で強調される単語と、弱く発音される単語があります。例えば、GO TO BEDではGOとBEDは強く発音され、TOはほとんど聞こえないぐらいの弱さで発音されます。" 
						elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)>=f1lowlim
							r$ = "いくつか発音が不明瞭な部分があり、会話をするのに躊躇しているように見受けられます。短母音や二重母音（例day,here）や子音の有声音、無声音の発音に注意し話す必要があります。また、単語の発音の強弱のつけ方に気を付ける必要があります。例えばBANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。また、文章の中で強調される単語と、弱く発音される単語があります。例えば、GO TO BEDではGOとBEDは強く発音され、TOはほとんど聞こえないぐらいの弱さで発音されます。" 
					elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)<f1lowlim
						r$ = "発音に少し不明瞭な部分があります。または、単語の強弱のつけ方が間違っている部分があります。短母音や二重母音（例day,here）や子音の有声音、無声音の発音に注意し話す必要があります。また、単語の発音の強弱のつけ方に気を付ける必要があります。例えばBANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。また、文章の中で強調される単語と、弱く発音される単語があります。例えば、GO TO BEDではGOとBEDは強く発音され、TOはほとんど聞こえないぐらいの弱さで発音されます。" 
				else 
					r$ = "発音に不明瞭な部分があります。または/さらに、単語の強弱のつけ方が間違っている部分があります。短母音や二重母音（例day,here）や子音の有声音、無声音の発音に注意し話す必要があります。また、単語の発音の強弱のつけ方に気を付ける必要があります。例えばBANANAを発音する場合、２番目のNAを強く発音し、１，３番目のBAとNAは弱く発音します。また、文章の中で強調される単語と、弱く発音される単語があります。例えば、GO TO BEDではGOとBEDは強く発音され、TOはほとんど聞こえないぐらいの弱さで発音されます。"  
endif 
                              
#SCORING 
if f00<90 or f00>255 
         z=1.16 
               elsif f00<97 or f00>245 
                     z=2
                           elsif f00<115 or f00>245 
                                z=3
                     elsif f00<=245 or f00>=115 
						z=4
						else 
                         z=1                      
    endif

	if nuofwrdsinchunk>=6.24 and avepauseduratin<=1.0
		l=4
			elsif nuofwrdsinchunk>=6.24 and avepauseduratin>1.0
				l=3.6
					elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin<=1.15
						l=3.3
							elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin>1.15
								l=3
									elsif nuofwrdsinchunk<4.4 and avepauseduratin<=1.15
										l=2
											elsif nuofwrdsinchunk<=4.4 and avepauseduratin>1.15
												l=1.16
													else
														l=1
		endif
	if balance>=0.69 and avenumberofwords>=2.60 
		o=4
             elsif balance>=0.60 and avenumberofwords>=2.43  
               o=3.5 
			elsif balance>=0.5 and avenumberofwords>=2.25 
				o=3 
					elsif balance>=0.5 and avenumberofwords>=2.07 
						o=2 
						elsif balance>=0.5 and avenumberofwords>=1.95 
							o=1.16 
								else 
									o=1
		endif
	if speakingrate<=4.26 and speakingrate>=3.16 
           q=4    
             elsif speakingrate<=3.16 and speakingrate>=2.54 
               q=3.5
		elsif speakingrate<=2.54 and speakingrate>=1.91 
			q=3
                 elsif speakingrate<=1.91 and speakingrate>=1.28  
                     q=2    
                       elsif speakingrate<=1.28 and speakingrate>=1.0 
                         q=1.16         
                           else 
                             q=1        
		endif
	if balance>=0.69 and articulationrate>=4.54 
           w=4
             elsif balance>=0.60 and articulationrate>=4.22 
               w=3.5
		elsif balance>=0.50 and articulationrate>=3.91
			w=3
                 elsif balance>=0.5 and articulationrate>=3.59  
                     w=2
                       elsif balance>=0.5 and articulationrate>=3.10 
                          w=1.16
                             else 
                                w=1 
    endif       
	if inpro>=119 and ('f1norm'*1.1)>=f1lowlim
		r = 4
			elsif inpro>=119 and ('f1norm'*1.1)<f1lowlim
				r = 3.8	
					elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)>=f1lowlim
						r = 3.6
							elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)<f1lowlim
								r = 3.4
									elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)>=f1lowlim
										r= 3.2
								elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)<f1lowlim
									r = 2.8
							elsif inpro<80 and inpro>=70 and ('f1norm'*1.1)>=f1lowlim
								r = 2.4
						elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)>=f1lowlim
							r = 2
					elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)<f1lowlim
						r = 1.1
				else 
					r = 0.3 				
								
	endif 

# summarize SCORE in Info window
   totalscore =(l*2+z*4+o*3+q*3+w*4+r*4)/20

totalscale= 'totalscore'*25


if totalscore>=4 
Blue 
	s$="Excellent" 
	elsif totalscore>=3.80 and totalscore<4 
	s$="上級レベル４"  
	elsif totalscore>=3.60 and totalscore<3.80 
	s$="上級レベル３" 
	elsif totalscore>=3.5 and totalscore<3.6 
	s$="上級レベル２" 
	elsif totalscore>=3.3 and totalscore<3.5 
	s$="上級レベル１" 
	elsif totalscore>=3.15 and totalscore<3.3 
	s$="中級レベル５" 
	elsif totalscore>=3 and totalscore<3.15 
	s$="中級レベル４"
	elsif totalscore>=2.83 and totalscore<3 
	s$="中級レベル３" 
	elsif totalscore>=2.60 and totalscore<2.83 
	s$="中級レベル２" 
	elsif totalscore>=2.5 and totalscore<2.60 
	s$="中級レベル１"  
	elsif totalscore>=2.30 and totalscore<2.50 
	s$="初級レベル３" 
	elsif totalscore>=2.15 and totalscore<2.30 
	s$="初級レベル２" 
	elsif totalscore>=2 and totalscore<2.15 
	s$="初級レベル１" 
	elsif totalscore>=1.83 and totalscore<2 
	s$="初心者レベル５" 
	elsif totalscore>=1.66 and totalscore<1.83 
	s$="初心者レベル４" 
	elsif totalscore>=1.50 and totalscore<1.66 
	s$="初心者レベル３"  
	elsif totalscore>=1.33 and totalscore<1.50 
	s$="初心者レベル２" 
	else 
	s$="初心者レベル１" 
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

#vvv=a+('totalscale'/100)
vvv=totalscore+('totalscale'/100)

if vvv>=4
     u=4*(1-(randomInteger(1,16)/100))
	else 
	   u=vvv-(randomInteger(1,16)/100) 
endif

if totalscore>=4
	xx=30 
	elsif totalscore>=3.80 and totalscore<4 
	xx=29 
	elsif totalscore>=3.60 and totalscore<3.80 
	xx=28 
	elsif totalscore>=3.5 and totalscore<3.6 
	xx=27 
	elsif totalscore>=3.3 and totalscore<3.5 
	xx=26 
	elsif totalscore>=3.15 and totalscore<3.3 
	xx=25 
	elsif totalscore>=3.08 and totalscore<3.15 
	xx=24
	elsif totalscore>=3 and totalscore<3.08 
	xx=23
	elsif totalscore>=2.83 and totalscore<3 
	xx=22 
	elsif totalscore>=2.60 and totalscore<2.83 
	xx=21 
	elsif totalscore>=2.5 and totalscore<2.60 
	xx=20 
	elsif totalscore>=2.30 and totalscore<2.50 
	xx=19 
	elsif totalscore>=2.23 and totalscore<2.30 
	xx=18
	elsif totalscore>=2.15 and totalscore<2.23 
	xx=17
	elsif totalscore>=2 and totalscore<2.15 
	xx=16 
	elsif totalscore>=1.93 and totalscore<2 
	xx=15
	elsif totalscore>=1.83 and totalscore<1.93 
	xx=14
	elsif totalscore>=1.74 and totalscore<1.83 
	xx=13
	elsif totalscore>=1.66 and totalscore<1.74 
	xx=12
	elsif totalscore>=1.50 and totalscore<1.66 
	xx=11 
	elsif totalscore>=1.33 and totalscore<1.50 
	xx=10 
	else 
	xx=9 
endif

overscore = xx*4/30
ov = overscore


if s$="L1" 
	level$= " ネイティブスピーカー並みのレベルで、学問的、専門的に複雑な会話を高いレベルで話す事が可能です。また、会話の中の重要な部分も分かりやすく、トピックに合わせて適切に表現が出来ている為、コミュニケーションを容易にとる事が出来ます。."
		elsif s$="L2" 
			level$= "中、上級レベルで、よく話題にするトピック等、慣れている会話であれば問題なく会話できますが、専門的で複雑な話題になると単語に限りが見受けられます。普段から様々なトピックを話題にし、自らの考えを表現したり、他者とのディスカッションや、話す内容の順を追って伝えられるよう意識すると良いでしょう。また日々の学習により、自分の考えを伝える、自ら話題を提供する、自発的に発言する事に自信がもてるようにすると良いでしょう。"  
	   elsif s$="L3"
		level$="簡単で、話慣れている会話であれば短い文章を使い、自分の考えを表現できています。また、一般的な質問や、指示であれば理解し答える事が出来ています。実際に会話をすることで会話に慣れ、まずは短い文でも自信を持って自分の考えを表現する事が出来るようになるでしょう。 "
		  elsif s$="L4"
			level$="慣れている会話や良く使う言葉使い、簡単な会話であれば話す事が出来ます。また、自分で経験もしくは知っている内容の話題であれば、簡単な文章で表現する事が可能です。"
	else
	  level$= "初心者"
endif

qaz = 0.18

rr = (r*4+q*2+z*1)/7
lu = (l*1+w*2+inpro*4/125)/4
td = (w*1+o*2+inpro*1/125)/3.25
facts=(ln(7/4)*4/7+ln(7/2)*2/7+ln(7)*1/7+ln(4)*1/4+ln(2)*1/2+ln(4)*1/4+ln(3.25)*1/3.25+ln(3.25/2)*2/3.25+ln(3.25/0.25)*0.25/3.25+ln(14.25/7)*7/14.25+ln(14.25/4)*4/14.25+ln(14.25/3.35)*3.25/14.25)
#totsco = (r*ln(7/4)*4/7+q*ln(7/2)*2/7+z*ln(7)*1/7+l*ln(4)*1/4+w*ln(2)*1/2+ln(4)*1/4*inpro*4/125+w*ln(3.25)*1/3.25+o*ln(3.25/2)*2/3.25+ln(3.25/0.25)*0.25/3.25*inpro*4/125)/facts

if totalscore>=4
      totsco=3.9
       else
         totsco=totalscore  
 endif

rrr = rr*qaz
lulu = lu*qaz
tdtd = td*qaz
totscoo = totsco*qaz 
               
Font size... 8
Blue
	Draw arc... 0 0 (4*qaz) 0 90 
        Text... (3.5*qaz) Centre 0 Half '上級' 
Green
	Draw arc... 0 0 (3*qaz) 0 90  
        Text... (2.5*qaz) Centre 0 Half '中級' 
Maroon
	Draw arc... 0 0 (2*qaz)  0 90 
        Text... (1.5*qaz) Centre 0 Half '初級'
Red
	Draw arc... 0 0 (1*qaz) 0 90  
        Text... (0.5*qaz) Centre 0 Half '初心者' 
Black
	Draw line... 0 0 0 6*qaz

whx=rrr*cos(1.309)
why=rrr*sin(1.309)
who=4*qaz
		
Font size... 10
if totsco>=3.17
	Blue
	Draw circle... (totscoo)*cos(0.5236) (totscoo)*sin(0.5236)+0.75*qaz (qaz/60)
		Text...  (totscoo)*cos(0.5236) Left (totscoo)*sin(0.5236)+2*(qaz/10)+0.75*qaz Half '総合評価'
		Draw arc... 0 0 totscoo 30 31 
		elsif totsco>=2.17 and totsco<3.17
		Green
		Draw circle... (totscoo)*cos(0.5236) (totscoo)*sin(0.5236)+0.5625*qaz (qaz/60)
		Text...  (totscoo)*cos(0.5236) Left (totscoo)*sin(0.5236)+2*(qaz/10)+0.5625*qaz Half '総合評価'
		Draw arc... 0 0 totscoo 30 31	
		elsif totsco>=1.17 and totsco<2.17
		Maroon
		Draw circle... (totscoo)*cos(0.5236) (totscoo)*sin(0.5236)+0.37*qaz (qaz/60)
		Text...  (totscoo)*cos(0.5236) Left (totscoo)*sin(0.5236)+2*(qaz/10)+0.37*qaz Half '総合評価'
		Draw arc... 0 0 totscoo 30 31	
		else
		Red
		Draw circle... (totscoo)*cos(0.5236) (totscoo)*sin(0.5236)+0.1875*qaz (qaz/60)
		Text...  (totscoo)*cos(0.5236) Left (totscoo)*sin(0.5236)+2*(qaz/10)+0.1875*qaz Half '総合評価'
		Draw arc... 0 0 totscoo 30 31		
endif				

Font size... 8

if rr>=3.17
	Blue
	Draw circle... whx why+1.8*qaz (qaz/60)
	Text... whx Centre why+3*(qaz/10)+1.8*qaz Half '伝え方'
	Draw arc... 0 0 rrr 75 76
	elsif rr>=2.17 and rr<3.17
	Green
	Draw circle... whx why+1.35*qaz (qaz/60)
	Text... whx Centre why+3*(qaz/10)+1.35*qaz Half '伝え方'
	Draw arc... 0 0 rrr 75 76	
	elsif rr>=1.17 and rr<2.17
	Maroon
	Draw circle... whx why+0.9*qaz (qaz/60)
	Text... whx Centre why+3*(qaz/10)+0.9*qaz Half '伝え方'
	Draw arc... 0 0 rrr 75 76
	else
	Red
	Draw circle... whx why+0.33*qaz (qaz/60)
	Text... whx Centre why+3*(qaz/10)+0.33*qaz Half '伝え方'
	Draw arc... 0 0 rrr 75 76		
endif				

if lu>=3.17				
	Blue
	Draw circle... lulu*cos(0.785398) lulu*sin(0.785398)+qaz (qaz/60)
	Text... lulu*cos(0.785398) Left lulu*sin(0.785398)+3*(qaz/10)+qaz Half '理解力'
	Draw arc... 0 0 lulu 45 46
	elsif lu>=2.17 and lu<3.17
	Green
	Draw circle... lulu*cos(0.785398) lulu*sin(0.785398)+0.75*qaz (qaz/60)
	Text... lulu*cos(0.785398) Left lulu*sin(0.785398)+3*(qaz/10)+0.75*qaz Half '理解力'
	Draw arc... 0 0 lulu 45 46	
	elsif lu>=1.17 and lu<2.17
	Maroon
	Draw circle... lulu*cos(0.785398) lulu*sin(0.785398)+0.5*qaz (qaz/60)
	Text... lulu*cos(0.785398) Left lulu*sin(0.785398)+3*(qaz/10)+0.5*qaz Half '理解力'
	Draw arc... 0 0 lulu 45 46	
	else
	Red
	Draw circle... lulu*cos(0.785398) lulu*sin(0.785398)+0.25*qaz (qaz/60)
	Text... lulu*cos(0.785398) Left lulu*sin(0.785398)+3*(qaz/10)+0.25*qaz Half '理解力'
	Draw arc... 0 0 lulu 45 46			
endif
				
if td>=3.17
	Blue
	Draw circle... tdtd*cos(1.0472) tdtd*sin(1.0472)+1.3*qaz (qaz/60)
	Text... tdtd*cos(1.0472) Centre tdtd*sin(1.0472)+3*(qaz/10)+1.3*qaz Half 'テーマ力'
	Draw arc... 0 0 tdtd 60 61 
	elsif td>=2.17 and td<3.17
	Green
	Draw circle... tdtd*cos(1.0472) tdtd*sin(1.0472)+0.975*qaz (qaz/60)
	Text... tdtd*cos(1.0472) Centre tdtd*sin(1.0472)+3*(qaz/10)+0.975*qaz Half 'テーマ力'
	Draw arc... 0 0 tdtd 60 61 	
	elsif td>=1.17 and td<2.17
	Maroon
	Draw circle... tdtd*cos(1.0472) tdtd*sin(1.0472)+0.65*qaz (qaz/60)
	Text... tdtd*cos(1.0472) Centre tdtd*sin(1.0472)+3*(qaz/10)+0.65*qaz Half 'テーマ力'
	Draw arc... 0 0 tdtd 60 61 	
	else
	Red
	Draw circle... tdtd*cos(1.0472) tdtd*sin(1.0472)+0.325*qaz (qaz/60)
	Text... tdtd*cos(1.0472) Centre tdtd*sin(1.0472)+3*(qaz/10)+0.325*qaz Half 'テーマ力'
	Draw arc... 0 0 tdtd 60 61 		
				
endif

Font size... 9
Black
Text... 2.65*qaz Left 5.5*qaz Half 総合評価
Font size... 6
Text... 2.65*qaz Left 5.15*qaz Half 総合評価の％は標準英語を基準とし、 
Text... 2.65*qaz Left 5*qaz Half 会話の伝わりやすさ、色々な分野に対しての知識力や
Text... 2.65*qaz Left 4.85*qaz Half 質問に対しすぐ返答が出来、シチュエーションに合わせて
Text... 2.65*qaz Left 4.7*qaz Half 会話が出来ているかを評価しております。 
Text... 4.5*qaz Left 5.5*qaz Half 1-発音
Text... 4.5*qaz Left 4.75*qaz Half 2-イントネーション-強勢
Text... 4.5*qaz Left 4*qaz Half 3-流暢さ
Text... 4.5*qaz Left 3.25*qaz Half 4-文法
Text... 4.5*qaz Left 2.5*qaz Half 5-文脈
Text... 4.5*qaz Left 1.75*qaz Half 6-発想力

if f00<90 or f00>255 
	Maroon
	Text... 4.5*qaz Left 4.5*qaz Half あまり自然ではありません
	elsif f00<97 or f00>245 
	Green
	Text... 4.5*qaz Left 4.5*qaz Half まあまあ自然です
	elsif f00<115 or f00>245 
	Blue
	Text... 4.5*qaz Left 4.5*qaz Half 自然です 	
	elsif f00<=245 and f00>=115
	Text... 4.5*qaz Left 4.5*qaz Half とても自然です 
	else
	Red
	Text... 4.5*qaz Left 4.5*qaz Half 不自然です
endif

if nuofwrdsinchunk>=6.24 and avepauseduratin<=1.0 
	Blue
	Text... 4.5*qaz Left 3*qaz Half 専門的レベル
	elsif nuofwrdsinchunk>=6.24 and avepauseduratin>1.0 
	Text... 4.5*qaz Left 3*qaz Half 上級レベル 
	elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin<=1.15 
	Green
	Text... 4.5*qaz Left 3*qaz Half 中上級レベル 
	elsif nuofwrdsinchunk>=4.4 and nuofwrdsinchunk<=6.24 and avepauseduratin>1.15 
	Text... 4.5*qaz Left 3*qaz Half 中級レベル 
	elsif nuofwrdsinchunk<4.4 and avepauseduratin<=1.15 
	Maroon
	Text... 4.5*qaz Left 3*qaz Half 初-中級レベル 
	elsif nuofwrdsinchunk<=4.4 and avepauseduratin>1.15
	Red
	Text... 4.5*qaz Left 3*qaz Half 初級レベル 
	else
	Text... 4.5*qaz Left 3*qaz Half 初心者レベル 
endif
 
if balance>=0.69 and avenumberofwords>=2.60 
	Blue
	Text... 4.5*qaz Left 2.25*qaz Half とても自然に話しています
	elsif balance>=0.60 and avenumberofwords>=2.43 
	Green
	Text... 4.5*qaz Left 2.25*qaz Half とても分かりやすい文脈で
	Text... 4.5*qaz Left 2.10*qaz Half 話しています
	elsif balance>=0.5 and avenumberofwords>=2.25 
	Text... 4.5*qaz Left 2.25*qaz Half 分かりやすいです 
	elsif balance>=0.5 and avenumberofwords>=2.07 
	Maroon
	Text... 4.5*qaz Left 2.25*qaz Half 理解しながら進めている事が
	Text... 4.5*qaz Left 2.10*qaz Half 見受けられます	
	elsif balance>=0.5 and avenumberofwords>=1.95 
	Red
	Text... 4.5*qaz Left 2.25*qaz Half 会話にまとまりが
	Text... 4.5*qaz Left 2.10*qaz Half 無い状態です
	else 
	Text... 4.5*qaz Left 2.25*qaz Half 会話に不慣れな状況が 
	Text... 4.5*qaz Left 2.10*qaz Half 見受けられます	
endif

if speakingrate<=4.26 and speakingrate>=3.16 
	Blue
	Text... 4.5*qaz Left 3.75*qaz Half ネイティブスピーカー並みです
	elsif speakingrate<=3.16 and speakingrate>=2.54 
	Green
	Text... 4.5*qaz Left 3.75*qaz Half とても流暢です 
	elsif speakingrate<=2.54 and speakingrate>=1.91 
	Maroon
	Text... 4.5*qaz Left 3.75*qaz Half 流暢です  
	elsif speakingrate<=1.91 and speakingrate>=1.28	
	Text... 4.5*qaz Left 3.75*qaz Half 少しなめらかで無い部分があるようです 	
	elsif speakingrate<=1.28 and speakingrate>=1.0
	Red
	Text... 4.5*qaz Left 3.75*qaz Half なめらかで無い部分があるようです 
	else
	Text... 4.5*qaz Left 3.75*qaz Half 流暢ではありません  
endif

if balance>=0.69 and articulationrate>=4.54 
	Blue
	Text... 4.5*qaz Left 1.5*qaz Half 専門的な話題も
	Text... 4.5*qaz Left 1.35*qaz Half 問題なく出来ます 	
	elsif balance>=0.60 and articulationrate>=4.22 
	Text... 4.5*qaz Left 1.5*qaz Half ほとんどの話題は 
	Text... 4.5*qaz Left 1.35*qaz Half 問題なく出来きます	
	elsif balance>=0.50 and articulationrate>=3.91 
	Green
	Text... 4.5*qaz Left 1.5*qaz Half 得意な分野の話題は
	Text... 4.5*qaz Left 1.35*qaz Half 問題なく出来ます 	
	elsif balance>=0.5 and articulationrate>=3.59 
	Maroon
	Text... 4.5*qaz Left 1.5*qaz Half 日常的で良く話す話題であれば 
	Text... 4.5*qaz Left 1.35*qaz Half 問題なく出来ます	
	elsif balance>=0.5 and articulationrate>=3.10 
	Red
	Text... 4.5*qaz Left 1.5*qaz Half 決まったパターンの話題であれば
	Text... 4.5*qaz Left 1.35*qaz Half 問題なく出来ます	
	else
	Text... 4.5*qaz Left 1.5*qaz Half 話慣れていないように
	Text... 4.5*qaz Left 1.35*qaz Half 見受けられます
endif	
	
if inpro>=119 and ('f1norm'*1.1)>=f1lowlim 
	Blue
	Text... 4.5*qaz Left 5.25*qaz Half ネイティブスピーカー 
	elsif inpro>=119 and ('f1norm'*1.1)<f1lowlim 
	Text... 4.5*qaz Left 5.25*qaz Half ネイティブスピーカーの様 
	elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)>=f1lowlim
	Text... 4.5*qaz Left 5.25*qaz Half 流暢 
	elsif inpro<119 and inpro>=100 and ('f1norm'*1.1)<f1lowlim
	Text... 4.5*qaz Left 5.25*qaz Half 素晴らしい
	elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)>=f1lowlim
	Green
	Text... 4.5*qaz Left 5.25*qaz Half とても良い 
	elsif inpro<100 and inpro>=80 and ('f1norm'*1.1)<f1lowlim
	Text... 4.5*qaz Left 5.25*qaz Half 良い 
	elsif inpro<80 and inpro>=70 and ('f1norm'*1.1)>=f1lowlim
	Maroon
	Text... 4.5*qaz Left 5.25*qaz Half 平均的 
	elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)>=f1lowlim 
	Text... 4.5*qaz Left 5.25*qaz Half 初級 
	elsif inpro<70 and inpro>=60 and ('f1norm'*1.1)<f1lowlim
	Red
	Text... 4.5*qaz Left 5.25*qaz Half 初級
	else
	Text... 4.5*qaz Left 5.25*qaz Half 聞取り不可能 
endif 

if originaldur>=60 
	Text... 4.5*qaz Left 1*qaz Half 
	else 
	Text... 4.5*qaz Left 1*qaz Half **60秒以下の音声です 
endif 
if speakingtot>=polish 
	Text... 4.5*qaz Left 0.75*qaz Half 
	else 
	Text... 4.5*qaz Left 0.75*qaz Half **音声の中に長い停止時間があります 
	endif 
	if f1norm>395 or eeee>395 
	Text... 4.5*qaz Left 0.5*qaz Half **音声がクリアではありません 
	else 
	Text... 4.5*qaz Left 0.5*qaz Half 
endif
	
Font size... 9
if totalscore>=4
Blue
	Text... 3.5*qaz Left 5.5*qaz Half 100'/, 
	elsif totalscore>=3.80 and totalscore<4 
	Text... 3.5*qaz Left 5.5*qaz Half 97'/, 
	elsif totalscore>=3.60 and totalscore<3.80 
	Text... 3.5*qaz Left 5.5*qaz Half 93'/, 
	elsif totalscore>=3.5 and totalscore<3.6 
	Text... 3.5*qaz Left 5.5*qaz Half 90'/, 
	elsif totalscore>=3.3 and totalscore<3.5 
	Text... 3.5*qaz Left 5.5*qaz Half 86'/, 
	elsif totalscore>=3.15 and totalscore<3.3 
	Text... 3.5*qaz Left 5.5*qaz Half 82'/, 
	elsif totalscore>=3 and totalscore<3.15 
	Text... 3.5*qaz Left 5.5*qaz Half 77'/, 
	elsif totalscore>=2.83 and totalscore<3 
	Text... 3.5*qaz Left 5.5*qaz Half 73'/, 
	elsif totalscore>=2.60 and totalscore<2.83 
	Text... 3.5*qaz Left 5.5*qaz Half 67'/, 
	elsif totalscore>=2.5 and totalscore<2.60 
	Text... 3.5*qaz Left 5.5*qaz Half 63'/,
	elsif totalscore>=2.30 and totalscore<2.50 
	Text... 3.5*qaz Left 5.5*qaz Half 60'/,
	elsif totalscore>=2.15 and totalscore<2.30 
	Text... 3.5*qaz Left 5.5*qaz Half 57'/, 
	elsif totalscore>=2 and totalscore<2.15 
	Text... 3.5*qaz Left 5.5*qaz Half 50'/, 
	elsif totalscore>=1.83 and totalscore<2 
	Text... 3.5*qaz Left 5.5*qaz Half 47'/, 
	elsif totalscore>=1.66 and totalscore<1.83 
	Text... 3.5*qaz Left 5.5*qaz Half 43'/, 
	elsif totalscore>=1.50 and totalscore<1.66 
	Text... 3.5*qaz Left 5.5*qaz Half 37'/, 
	elsif totalscore>=1.33 and totalscore<1.50 
	Text... 3.5*qaz Left 5.5*qaz Half 34'/, 
	else 
	Text... 3.5*qaz Left 5.5*qaz Half 25'/, 
endif

Save as 300-dpi PNG file... C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\RESULTS/'soundname$'.jpg

Erase all

         writeFileLine: "C:\Users\Sabahi.s\Desktop\MYSOL Scoring File\RESULTS/'soundname$'.doc", newline$
	 ... ,"*************************************************************************", newline$
	 ... ,"*************************************************************************", newline$
	 ... ,"名前", tab$, tab$, tab$,tab$,tab$, soundname$, newline$
     ... ,"単語数", tab$, tab$,tab$,tab$,tab$,'nuofwrds:0', newline$   
     ... ,"停止回数", tab$, tab$,tab$,tab$, 'npause', newline$ 
   	 ... ,"全録音時間  (s)", tab$, tab$,tab$, 'originaldur:2', newline$
   	 ... ,"音声録音時間 (s)", tab$, tab$,tab$, 'speakingtot:2', newline$
	 ... ,"*************************************************************************", newline$
   	 ... ,"*************************************************************************", newline$	 
	 ... ,warning0$, newline$
	 ... ,warning1$, newline$ 
	 ... ,warning2$, newline$
	 ... ,warning3$, newline$
	 ... ,"*************************************************************************", newline$
   	 ... ,"*************************************************************************", newline$
   	 ... ,"総合評価  ---TOEFL iBT Score scale between 0 (low) and 30 (high)--",'xx:1', newline$
	 ... ,"総合レベル ----Level scale: Weak, Limited, Fair, Good --",s$, newline$
 	 ... ,"*************************************************************************", newline$
   	 ... ,"*************************************************************************", newline$	 
	 ... ,"発音", newline$										
   	 ... , r$, newline$												  
   	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"イントネーション-強勢", newline$									
   	 ... , z$, newline$	  
   	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"流暢さ", newline$			
   	 ... , q$, newline$					
  	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"文法※1", newline$					
   	 ... , l$, newline$				
  	 ... ,"------------------------------------------------------------------------", newline$
   	 ... ,"文脈※２", newline$							 
   	 ... , o$, newline$				
   	 ... ,"------------------------------------------------------------------------", newline$ 
   	 ... ,"発想力※３", newline$								
   	 ... , w$, newline$
   	 ... ,"*********************************************************", newline$
   	 ... ,"※１ここでは、標準英語を基準とし単語や文法の使い方を表しています。", newline$   
   	 ... ,"※２ここでは、整った文脈と会話の流れにあった単語を使用しているかを表しています。", newline$
   	 ... ,"※３ここでは、会話にあった考えや発想をしているかを表しています。", newline$
	 ... ,"------------------------------------------------------------------------", newline$
	 ... ,"------------------------------------------------------------------------", newline$
endfor

