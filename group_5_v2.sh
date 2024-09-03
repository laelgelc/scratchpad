# covid only abstracts and full texts:
# https://ftp.ncbi.nlm.nih.gov/pub/lu/LitCovid/
# https://ftp.ncbi.nlm.nih.gov/pub/lu/LitCovid/litcovid2pubtator.xml.gz

# various fields of medicine:
# https://ftp.ncbi.nlm.nih.gov/pub/lu/PubTatorCentral/PubTatorCentral_BioCXML/
# https://ftp.ncbi.nlm.nih.gov/pub/lu/PubTatorCentral/PubTatorCentral_BioCXML/BioCXML.0.tar

# NEXT VERSION -- DOWNLOAD ONLY HYDROXYCHLOROQUINE RELATED ARTICLES: [this will download only the references, not the full text]
# https://www.ncbi.nlm.nih.gov/research/coronavirus/docsum?filters=e_drugs.Hydroxychloroquine&sort=score%20desc&page=1

# I CONVERTED THE LOGDICE VALUES FOR EACH VARIABLE TO 1; THEREFORE THE VARIABLE VALUES WERE EITHER 1 OR 0, NOT THE LOGDICE
# I RAN THE FACTOR ANALYSIS USING THE BINARY DATA
# THIS TRANSFORMATION IS AT THE END OF THE SAS ROUTINE BELOW


### PSEUDO-SCIENCE

splitfiles () {
    
echo "--- head: grabbing a large chunk ..."

head -c 350000000 litcovid2pubtator.xml > a

echo "--- sed : formatting...  " 
sed 's/<infon key=/~<infon key=/g' a | tr '~' '\n' > trparsed

echo "--- splitting into files...  " 
mkdir -p temp
find temp -type f -exec rm -f {} +

#split -p '<document' -a6 trparsed temp/
csplit -f temp/ -b "%06d" trparsed '/<document/' '{*}'

}

refcleanup () {

ls temp | nl -nrz > files
mkdir -p corpus/ref_temp corpus/ref
rm -f corpus/ref_temp/* corpus/ref/*

rm -f x*
while read n file
do
    echo "-- $n --"
    grep -A1 -E 'infon key="section_type">ABSTRACT|infon key="section_type">CASE|infon key="section_type">CONCL|infon key="section_type">DISCUSS|infon key="section_type">INTRO|infon key="section_type">METHODS|infon key="section_type">RESULTS' temp/$file | sed -e 's/<text>/<text>~/g' -e 's;</text>;~</text>;g' | tr '~' '\n' | grep -v -E '^<infon|</text' > corpus/ref_temp/$file
done < files

# delete short files, ie at least 100 'lines' (each line can be a paragraph or a heading, etc), to avoid letters to the editor
wc -l corpus/ref_temp/* | sed 's/^[ ]*//' | grep -v -E '^[8-9]. |^... ' | nl -nrz > dfiles

while read id n dfile
do
    echo "-- $id -- "
    rm -f $dfile
done < dfiles

# not all files have pmid's -- these are short texts, not articles
rg '<infon key="article-id_pmid">' temp/* | tr ':' ' ' | tr '>' ' ' | cut -d' ' -f1,4 | cut -d'<' -f1 | sed 's;temp/;;' | sort > pmids.txt

# list remaining files
ls corpus/ref_temp > files
#join -1 1 -2 1 files pmids.txt | gshuf | head -1001 | nl -nrz > pfiles
join -1 1 -2 1 files pmids.txt | shuf | head -1001 | nl -nrz > pfiles

while read n file pmid
do
    rg -m1 -w $pmid litcovid.export.tsv | sed "s/^/f:ref_"$n".txt|x:$file|pmid:/" | tr '\t' '|' | sed -e 's/|/|t:/3' -e 's/|/|j:/4'
done < pfiles > ref_file_index.txt

IFS='|'  # ticks are REQUIRED; IFS=| is wrong
while read refx filex pmid title journal
do
    echo "-- $refx --"
    file=$( echo $filex | sed 's/x://' )
    ref=$( echo $refx | sed 's/f://' )
    sed 's/^\-\-//' corpus/ref_temp/$file > corpus/ref/$ref
done < ref_file_index.txt
IFS=$' \t\n'    # TO RESTORE TO ORIGINAL VALUE

# rg -A1 '"section_type"' temp/* | rg -v 'section_type'  | cut -d'-' -f2- | sort | uniq 

}

pseudocleanup () {

find corpus/pseudo_temp -type f | cut -d'/' -f3 | cut -d'_' -f1 | sed 's/000078/00078/' > a
find corpus/pseudo_temp -type f > b
paste a b | grep -v DS | sort > files
find corpus/pseudo -type f -exec rm {} +

while read n file
do
    cat "$file" | tr -d '\r' | tr '\t' ' ' | sed -e 's/A B S T R A C T//g' -e 's/R E T R A C T E D//g' | tr -s ' ' > corpus/pseudo/pseudo_$n.txt
done < files

}

kwcounts () {

mkdir -p kwcounts
find kwcounts -type f -exec rm -f {} +
find kwcounts -type d -exec rmdir -p {} +

mkdir -p types/pseudo types/ref

# grab types for each text

ls corpus/pseudo > target_files
while read file
do
    echo "--- $file ---"
    cat corpus/pseudo/$file | tr ' \t-' '\n' | tr -d '[\.,;:\?!()"]' | tr '[:upper:]' '[:lower:]' | grep -v -e '[0-9]' -e '&' -e '\#' -e '<' -e '>' | grep '[a-z]' | sort | uniq > types/pseudo/$file
done < target_files

ls corpus/ref > ref_files
while read file
do
    echo "--- $file ---"
    cat corpus/ref/$file | tr ' \t-' '\n' | tr -d '[\.,;:\?!()"]' | tr '[:upper:]' '[:lower:]' | grep -v -e '[0-9]' -e '&' -e '\#' -e '<' -e '>' | grep '[a-z]' | sort | uniq > types/ref/$file
done < ref_files

find types/ref -type f -exec cat {} + > x ; sort x | uniq -c | grep -v ' 1 ' > all_ref
find types/pseudo -type f -exec cat {} + > x ; sort x | uniq -c | grep -v ' 1 ' > all_target

python join.py # outputs to c
sort c > cc ; mv cc c

    wctarget=$( cat target_files | wc -l | tr -dc '[0-9]' )
    wcref=$( cat ref_files | wc -l | tr -dc '[0-9]' ) 

    sed -e "s/$/ $wctarget $wcref/" c | sed -f stoplist.sed | nl -nrz > kwcounts/kwcounts.txt
    last=$( wc -l kwcounts/kwcounts.txt | tr -dc '[0-9]' )

    echo "n word targetfreq targetwca perthoua reffreq refwca perthoub " > kwcounts/kwdata.txt

    while read n word targetfreq reffreq targetwc refwc
    do
          echo "--- kwcounts/kwdata.txt ($n of $last ) for $word ---"
          perthoua=$( echo " ( $targetfreq / ( $targetwc + .1 ) ) * 1000 " | bc -l | xargs printf "%.*f\n" 2 )   # freq per thousand words in corpus 1
          perthoub=$( echo " ( $reffreq / ( $refwc + .1 ) ) * 1000 " | bc -l | xargs printf "%.*f\n" 2 )   # freq per thousand words in corpus 2
          echo "$n $word $targetfreq $targetwc $perthoua $reffreq $refwc $perthoub " >> kwcounts/kwdata.txt
      done < kwcounts/kwcounts.txt
      
      grep -v -e '0.00 $' -e '[a-z0-9] [0-9]* [0-9]* 0' kwcounts/kwdata.txt > kwcounts/kwdata_filtered.txt  # CUT-OFF: 0 freq in ref corpus

}

keywords () {

find keywords -type f -exec rm -f {} +
find keywords -type d -exec rmdir -p {} +
mkdir -p keywords

tail +2 kwcounts/kwdata_filtered.txt > c

echo "word corpus1freq per1000textsC1 corpus2freq per1000textsC2 perthouratio expected_C1 expected_C2 LL LLxratio" > keywords/keywords.txt

while read id word a wca perthoua b wcb perthoub # a=target corpus, b=refcorpus
do

    last=$( cat c | wc -l | tr -dc '[0-9]' )

    echo "----- ($id / $last ) log likelihood $word ------"

    c=$( ls corpus/pseudo | wc -l | tr -dc '[0-9]'  ) # total texts in target corpus
    d=$( ls corpus/ref | wc -l | tr -dc '[0-9]'  ) # total texts in reference corpus

    if [[ "$perthoub" = "0.00" ]]; then
       perthoub=0.01   # so the divisions work when the freq in corpus 2 is zero
    else
       :
    fi

    perthoubx=$( echo $perthoub | xargs printf "%.*f\n" 1 )

    perthouratio=$( echo " ( $perthoua / $perthoub ) " | bc -l | xargs printf "%.*f\n" 1 ) # ratio 'per-thousand texts' 

    e1=$( echo "$c * ( $a + $b ) / ( $c + $d )" | bc -l | xargs printf "%.*f\n" 2 )  # expected in  corpus 1
    e2=$( echo "$d * ( $a + $b ) / ( $c + $d )" | bc -l | xargs printf "%.*f\n" 2 ) # expected in  corpus 2
    ae1=$( echo " $a / $e1 " | bc -l )
    be2=$( echo " $b / $e2 " | bc -l )
    g2=$( echo " 2 * ( ( $a * l( $ae1 ) ) + ( $b * l( $be2 ) ) ) " | bc -l | xargs printf "%.*f\n" 2 ) 

    g2xratio=$( echo " $g2 * $perthouratio " | bc -l | xargs printf "%.*f\n" 2 ) 

    echo "$word $a $perthoua $b $perthoubx $perthouratio $e1 $e2 $g2 $g2xratio " >> keywords/keywords.txt

done < c

}

keywordselect () {
    
mkdir -p kw_results
rm -f kw_results/*

echo "word per1000textsC1 per1000textsC2 LL Ratio1x2 Ratio2x1 kw" > kw_results/kw_results.txt  # C1 = target corpus , C2 = ref corpus

cut -d' ' -f1,3,5,9 keywords/keywords.txt | tail +2 > keywords/kw

rm -f b

while read word per1000textsC1 per1000textsC2 LL
do

        echo "--- kw_results/kw_results.txt $word --- "

        c1norm=$( echo "($per1000textsC1 * 100)" +1 | bc  | xargs printf "%.*f\n" 0 )
        c2norm=$( echo "($per1000textsC2 * 100)" +1 | bc  | xargs printf "%.*f\n" 0 )

        ratio12=$( echo "$c1norm / $c2norm" | bc )
        ratio21=$( echo "$c2norm / $c1norm" | bc )

        ll2=$( echo $LL | tr -d '.' )  #remove decimal point

        #echo "C2NORM = $c2norm"

        if [ $ll2 -lt 384 ] 
             then
                 kw=notkw
        elif [ "$c1norm" -gt "$c2norm" ] 
             then
                kw=kwTARGET
        elif [ "$c1norm" -lt "$c2norm" ] 
             then
                 kw=kwREF
        else
                kw=kwnodec
        fi

        echo "$word $per1000textsC1 $per1000textsC2 $LL $ratio12 $ratio21 $kw" >> kw_results/kw_results.txt
done < keywords/kw

  sed -f stoplist.sed kw_results/kw_results.txt > z ; mv z kw_results/kw_results.txt
  
  head -1 kw_results/kw_results.txt > kw_results/TARGET_kw.txt
  grep kwTARGET kw_results/kw_results.txt >> kw_results/TARGET_kw.txt
  head -1 kw_results/kw_results.txt > kw_results/REF_kw.txt
  grep kwREF kw_results/kw_results.txt >> kw_results/REF_kw.txt
  head -1 kw_results/kw_results.txt > kw_results/NOTKW_kw.txt
  grep notkw kw_results/kw_results.txt >> kw_results/NOTKW_kw.txt

  tail +2 kw_results/REF_kw.txt | sort -t' ' -k4,4 -nr | head -50 > kw_results/top_REF_kw.txt 
  tail +2 kw_results/TARGET_kw.txt | sort -t' ' -k4,4 -nr  | head -50 > kw_results/top_TARGET_kw.txt 
  
  grep 'kwTARGET' kw_results/kw_results.txt | cut -d' ' -f1 | sort | nl -nrz > keywords_pseudo.txt
  grep 'kwREF' kw_results/kw_results.txt | cut -d' ' -f1 | sort | nl -nrz > keywords_ref.txt
  
}

nodes () {

mkdir -p nodes/files ; rm -f nodes/files/*
mkdir -p nodes/casesensitive ; rm -f nodes/casesensitive/*

for type in pseudo ref
do
    ls corpus/$type > files #; rm -f column_target
    while read file
    do
        echo "-- node formatting : $file --"
        cat corpus/$type/$file | tr -s ' ' | tr ' ' '\n' | grep -v '^$' > 5
        echo > t
        cat t 5 > 4 ; cat t t 5 > 3 ; cat t t t 5 > 2 ; cat t t t t 5 > 1
        tail +2 5 > 6 ; tail +3 5 > 7 ; tail +4 5 > 8 ; tail +5 5 > 9
        paste 1 2 3 4 5 6 7 8 9 | tr '\t' '|' | sed 's/\(.*\)\|\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)/w1:\1|w2:\2|w3:\3|w4:\4|node:\5|w6:\6|w7:\7|w8:\8|w9:\9/' | sed "s/^/f:"$file"|/"  > nodes/casesensitive/$file
        tr '[:upper:]' '[:lower:]' < nodes/casesensitive/$file > nodes/files/$file
    done < files
done

# filter lines by keywords

mkdir -p nodes/kw ; rm -f nodes/kw/*

for type in pseudo ref
do
    cut -f2 keywords_$type.txt | sed -e 's/^/node:/'  > keywords_rg_$type
done

# searching for pseudo and ref keywords in all files, regardless of whether they are from the pseudo or ref corpus
rm -f nodes/kw/*
for type in pseudo ref
do
    ls corpus/$type > files 
    while read file
    do
        echo "-- kw filtering : $file --"
        rg -f keywords_rg_pseudo nodes/files/$file > nodes/kw/"$file"
        rg -f keywords_rg_ref nodes/files/$file >> nodes/kw/"$file"
    done < files
done

}


wordfrequency () {

for type in target ref
do  
    echo "--- word frequency list for $type ---"
    cut -d'|' -f6 column_"$type" | cut -d':' -f2 | tr '[:upper:]' '[:lower:]' | grep -v '()' | tr -d '[:punct:]' | grep -v '[0-9]' | sort | uniq -c | sed 's/^[ ]*//' | grep '^[0-9]* [a-z]*$' | grep '[a-z]' > wordlist_"$type"
done

mkdir -p wordlists ; rm -f wordlists/*
for type in pseudo ref
do
    ls corpus/$type > files 
    while read file
    do
        echo "-- wordlist : $file --"
        cut -d'|' -f6 nodes/files/$file | cut -d':' -f2 | tr '[:upper:]' '[:lower:]' | grep -v '()' | tr -d '[:punct:]' | grep -v '[0-9]' | sort | uniq -c | sed 's/^[ ]*//' | grep '^[0-9]* [a-z]*$' | grep '[a-z]' > wordlists/$file
    done < files
done

}

collocates () {
    
mkdir -p nodes/punctuation collocates/files collocates/counts collocates/temp
rm -f nodes/punctuation/* collocates/files/* collocates/counts/* collocates/temp/*

for type in pseudo ref
do
    ls corpus/$type > files 
    while read file
    do
        echo "-- collocates : $file --"
        cut -d'|' -f2- nodes/kw/$file | sed -e 's/|w[2-9]:/|/g' -e 's/^w1://g'  -e 's/|node:/|NODEX /' -e 's/:/ COLON/g' -e 's/-/DASH/g' > b
        sh punctuation.awk | sed -e 's/|NODEX /|node:/g' -e 's/COLON/:/g' -e 's/DASH/-/g' > nodes/punctuation/$file    
    done < files
done

echo "--- python node_collocate : collocates/files/... "
python node_collocate.py

# removing stoplist words from collocates
# the stoplist for collocates is stoplist_collocates.sed even though the stoplist is processed through awk

for type in pseudo ref
do
    ls corpus/$type > files 
    while read file
    do
        #targetcount=$( rg -m1 -w $w wordlist_target | cut -d' ' -f1 )
        #refcount=$( rg -m1 -w $w wordlist_ref | cut -d' ' -f1 )
        echo "-- stoplist for collocates : $file --"
#        rg -v ' $' collocates/files/$file | sed -f collocates_stoplist.sed | sed 's/ [0-9]*$//' | sort | uniq -c | sed 's/^[ ]*//' | tr -s ' ' | rg '[a-z] [a-z]' | sed 's/^[ ]*//' | sed 's/^\([0-9]*\) \(.*\) \(.*\)/\2 \3 \1/' > collocates/temp/$file 
        rg -v ' $' collocates/files/"$file" | awk -f awk_collocates_stoplist.awk | sed 's/ [0-9]*$//' | sort | uniq -c | sed 's/^[ ]*//' | tr -s ' ' | rg '[a-z] [a-z]' | sed 's/^[ ]*//' | sed 's/^\([0-9]*\) \(.*\) \(.*\)/\2 \3 \1/' | awk -f awk_add_kw_prefix.awk > "collocates/temp/$file"
       
    done < files
done

python counts.py  # input: collocates/temp output: collocates/counts
python delete_na.py # output: collocates/counts 
python remove_faulty_lines.py # output: collocates/counts 

# add 'p_' for pseudo keywords or 'r_' for ref keywords to each line, and delete lines that have no prefix
mkdir -p collocates/kwprefix ; rm -f collocates/kwprefix/*
for type in pseudo ref
do
    ls corpus/$type > files 
    while read file
    do
        echo "-- adding kw prefix to nodes : $file --"
        cat collocates/counts/"$file" | awk -f awk_add_kw_prefix.awk > "collocates/kwprefix/$file"
    done < files
done

}

logdice () {

# Rychly 2008: Log-Dice: https://nlp.fi.muni.cz/raslan/2008/papers/13.pdf
# log2 = awk 'BEGIN { x = NUMBER_TO_CALCULATE; result = log(x) / log(2); print result }'
# logdice D = 14 + log2 * (2 fxy / (fx + fy))

# columns: logistic        adjusted                      3           132                        133
# columns: node_target     collocate_in_target_corpus    jointfreq   nodefreq_in_target_corpus  collocatefreq_in_target_corpus

# fxy=3 ; fx=132 ; fy=133
# logdice D = 14 + log2 * (2 * 3 / (132 + 133))
# logdice D = 14 + log2 * ( 6 / 265 )
# logdice D = 14 + log2 * .0226
# log2 = awk 'BEGIN { x = .0226 ; result = log(x) / log(2); print result }' = -5.46753
# logdice D = 14 + -5.46753 = 8.53247

# Excel : ref/logdice.xlsx

mkdir -p logdice ; rm -f logdice/* 
mkdir -p logdice_average ; rm -f logdice_average/*
mkdir -p no_repeats ; rm -f no_repeats/*
mkdir -p no_repeats_temp ; rm -f no_repeats_temp/*


python logdice.py  # input: collocates/kwprefix output: logdice/ ; {node} {collocate} {fxy} {fx} {fy} {logdice_value}
#python average_logdice.py  # input: logdice/ output: logdice_average/
python check_repeated.py  # input: logdice/  output: no_repeats_temp/ this identifies lines that have a 'node collocate' combination that is identifical to a collocation node combination in the same file, and adds 'REPEATED' to all such repeated lines but one ; {node} {collocate}
python delete_repeated.py  # input: no_repeats_temp/  output: no_repeats/ # this deletes lines that have REPEATED in them

}

selectfeatures () {
    
    # NO_REPEATS APPARENTLY DIDN'T WORK... REPETITIONS OF NODE + COLLOCATE STILL PERSIST (EACH HAS A DIFFERENT LOGDICE THOUGH...)
    
# echo "--- selecting collocations ... ---"
cat no_repeats/ref* | rg 'r_' | cut -d' ' -f1,2 | sed -f collocates_stoplist.sed | sort | uniq -c | sort -nr | grep -E ' [2-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] ' | head -500 | cut -c6- > selected_ref
cat no_repeats/pseudo* | rg 'p_' | cut -d' ' -f1,2 | sed -f collocates_stoplist.sed | sort | uniq -c | sort -nr | grep -E ' [2-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] ' | head -500 | cut -c6- > selected_pseudo

}

sas () {
    
cat selected_pseudo selected_ref > selectedwords

ls no_repeats > files

mkdir -p sas

rm -f sas/data.txt
while read file
do
    echo "--- sas/data.txt : "$file" --- "
    rg -f selectedwords no_repeats/$file | cut -d' ' -f1,2,6 | sed "s/^/$file /" >> sas/data.txt  
done < files

echo "--- var_index.txt ---"
nl -nrz selectedwords | sed 's/^/v/' | tr '\t' ' ' > var_index.txt
sed 's;\(.*\) \(.*\) \(.*\);s/ \2 \3 / \1 /;' var_index.txt > vars.sed

echo "--- formatting sas/data.txt ---"
sed -f vars.sed sas/data.txt > b 
cut -d' ' -f1 b | sort | uniq | nl -nrz | sed 's/^/t/' | tr '\t' ' ' > text_index.txt
sed 's;\(.*\) \(.*\);s/\2/\1/;' text_index.txt > text_index.sed
sed -f text_index.sed b | rg -v -e '[0-9] [p_]' -e '[0-9] [r_]' | sort | uniq > d

# find texts having the same variable with different logdice values
cut -d' ' -f1,2 d | sort | uniq -d > dupes

# grab the highest logdice for each of those
while read a b
do
    rg -w $a d | rg -w $b | sort -nr -t' ' -k3,3 | head -1 
done < dupes > replace

# remove the duplicate cases
sed 's;\(.*\) \(.*\);/\1 \2/d;' dupes > dupes.sed
sed -f dupes.sed d > e

# add back the fixed duplicate cases
cat e replace > sas/data.txt

# convert the sas data to binary 
cut -d' ' -f1-2 sas/data.txt | sed 's/$/ 1/' > b

# wcount
wc -w corpus/ref/* | grep -v total | sed 's/^[ ]*//' | sed 's;corpus/ref/;;' > wcount_ref.txt
wc -w corpus/pseudo/* | grep -v total | sed 's/^[ ]*//' | sed 's;corpus/ref/;;' > wcount_pseudo.txt
cat wcount_ref.txt wcount_pseudo.txt | sort -t' ' -k2,2 > w
join -1 2 -2 2 -o 1.1 -o 1.2 -o 2.1 text_index.txt w  > sas/wcount.txt

}

datamatrix () {

mkdir -p temp2

rm -f temp2/*

cut -d' ' -f1 sas/data.txt | uniq | sort > files

while read n word 
do
  echo "--- $n ---"
  rg -w $n sas/data.txt | sort -t' ' -k1,1 > a
  echo "$n" > temp2/$n
  join -a 1 -1 1 -2 1 -e 0 files a | sed "s/$/ $n 0/" | cut -d' ' -f3 >> temp2/$n
done < var_index.txt

echo "--- data.csv ...---"

awk '
        FNR==1 { col++ }
        FNR>max { max=FNR }
        { l[FNR,col]=$0 }
        END {
                for (i=1;i<=max;i++) {
                        for (j=1;j<=col;j++) {
                                printf "%-50s",l[i,j]
                        }
                        print ""
                }
        }
' temp2/* > u
tr -s ' ' < u | tr ' ' ',' | sed 's/,$//' > data.csv

}

correlation () {

echo "--- python correlation ... ---"

python3 corr.py > correlation

nlines=$( cat text_index.txt | wc -l | tr -dc '[0-9]' )

tail +2 correlation | tr -s ' ' | sed 's/^/CORR /' > bottom
head -1 correlation | tr -s ' ' | sed 's/^[ ]*//' | sed "s/\(v......\)/$nlines/g" | sed 's/^/N . /' > n

python3 std.py > s 
tr -s ' ' < s | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/STD	 . /' > std 
echo >> std

python3 mean.py > m 
tr -s ' ' < m | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/MEAN . /' > mean
echo >> mean

cat mean std n bottom > sas/corr.txt

}

formats () {

echo "PROC FORMAT library=work ;
  VALUE  \$lexlabels" > sas/word_labels_format.sas
tr '\t' ' ' < var_index.txt | sed 's/\(.*\) \(.*\) \(.*\)/"\1" = "\2 \3"/' >> sas/word_labels_format.sas
echo ";
run;
quit;" >> sas/word_labels_format.sas

cut -c1-9 text_index.txt | sed -e 's/ p/ pseudo/' -e 's/ r/ science/' > sas/metadata.txt

}

factorlist () {

html2text -nobs sas/output_group5/loadtable.html > a

rm -f x??
split -p'=====' a
ls x?? > files

while read file
do
  pole=$( grep '^Factor ' $file | cut -d' ' -f2,3 | sed -e 's/^/f/' -e 's/ //g' )
#  grep '^[0-9]' $file | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | cut -d' ' -f2 | grep -v '^$' | sed "s/^/$pole /" 
   grep '^[0-9]' $file | sed 's/)/ secondary/' | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | sed 's/ /_/2' | cut -d' ' -f2,4 | sed 's/ secondary/ (secondary)/' | grep -v '^$' | sed "s/^/$pole /" 
done < files > examples/factors
rm -f x??

}

examples () {

    # annotation for full texts
    
    # high-scoring texts to use as examples for each dim (up to)
    toptexts=5

    rm -f examples/full_*

    while read i pole subcorpus
    do

        column=$( echo " $i + 1 " | bc ) 
        cut -d',' -f1,"$column" sas/output_md_coursebooks/scores_only.csv | tail +2 > a

        echo "--- examples "f"$i""$pole"" ---" 

        if [ "$pole" == pos ] ; then
           sort -nr -k2,2 a | grep -v '\-' | head -20 | nl -nrz > files
        else
           sort -n -k2,2 a | grep '\-' | head -20 | nl -nrz > files
        fi
   
        # add corpus filename
        cut -f2 files > f
        rg -f f text_index.txt > rt
        
        # select files from subcorpus (ie pseudo or ref)
        paste files rt | tr '\t' ' ' | cut -d' ' -f1,2,3,5 | rg $subcorpus | head -"$toptexts" > g ; mv g files
   
        # list collocations, in normal and reverse order, filtering by subcorpus
        grep f"$i""$pole" examples/factors | rg " "$subcorpus"_" | tr '_' ' ' | cut -d' ' -f3,4 > a ; sed 's/\(.*\) \(.*\)/\2 \1/' a > b ; cat a b > c
        
        # make a sed file for annotating the vars
        while read a b
        do
            echo "s/ $a $b / ~textbf{$a} ~textbf{$b} /gI"  
            echo "s/ $a \([~a-zA-Z0-9{}]*\) $b / ~textbf{$a} \1 ~textbf{$b} /gI"  
            echo "s/ $a \([~a-zA-Z0-9{}]*\) \([~a-zA-Z0-9{}]*\) $b[\.,?!;:]* / ~textbf{$a} \1 \2 ~textbf{$b} /gI"  
            echo "s/ $a \([~a-zA-Z0-9{}]*\) \([~a-zA-Z0-9{}]*\) \([~a-zA-Z0-9{}]*\) $b[\.,?!;:]* / ~textbf{$a} \1 \2 \3 ~textbf{$b} /gI"  
        done < c > examples/colls_f"$i""$pole".sed
    
        while read n text score file
        do
            echo " --- $n examples/full_f"$i""$pole".txt ---"
            echo >> examples/full_f"$i""$pole"_"$n".txt
            folder=$( echo $file | cut -d'_' -f1 )
            echo "Text: corpus/$folder/$file " >> examples/full_f"$i""$pole"_"$n".txt
            tr -s '\n' ' ' < corpus/$folder/$file | tr -s ' ' | sed -f examples/colls_f"$i""$pole".sed | fmt >> examples/full_f"$i""$pole"_"$n".txt
        done < files 
   
    done < example_poles

}

wordclouds () {
    
mkdir -p wordclouds 

# dimensions (using types)

rm -f wordclouds/dim*.png

while read i pole subcorpus
do
        echo "--- wordclouds/dim_"f"$i""$pole""_wordcloud.png ---" 
        
        if [ "$subcorpus" == 'p' ] ; then
            subcorpus=pseudo
        else
            subcorpus=ref
        fi

        if [ "$pole" == pos ] ; then
           sort -nr -k2,2 a | grep -v -e '\-' -e '	0' | head -100 | cut -f1 | sort -n > files
        else
           sort -n -k2,2 a | grep -e '\-' | grep -v -e '	0' | head -100 | cut -f1 | sort -n > files
        fi

        grep "f"$i""$pole"" examples/factors  | grep -v '(secondary)' | cut -d' ' -f2 | sort -t' ' -k2,2 | uniq > c
                
        cat collocates/kwprefix/* | cut -d' ' -f1-3 | sed 's/ /_/' | sed -f wordclouds/stoplist.sed | sort > a
        
        join c a | awk '{ collocations[$1] += $NF } END { for (col in collocations) print col, collocations[col] }' | sed 's/ / , /' > wordclouds/wc.csv 
        
        if [ "$subcorpus" == pseudo ] ; then
        sed "s;FILENAME;wordclouds/dim_"$i""$pole"_wordcloud;" wordclouds/wcloud_template.py | sed -e 's/int(v)/float(v)/' -e 's/Oranges/Dark2/' -e 's/orange/yellow/' > p
        else
        sed "s;FILENAME;wordclouds/dim_"$i""$pole"_wordcloud;" wordclouds/wcloud_template.py | sed -e 's/int(v)/float(v)/' -e 's/Oranges/PuBu/' -e 's/orange/pink/' > p
        fi

        python3 p
   
done < example_poles

# factor loadings

html2text -nobs sas/output_group5/loadtable.html > a

rm -f x??
split -p'=====' a
ls x?? > files

rm -f wordclouds/loadings*.png

while read file
do
  fac=$( grep '^Factor ' $file | cut -d' ' -f2,3 | sed -e 's/^/f/' -e 's/ //g' )
  pole=$( echo $fac | tr -d '[f0-9]' ) 
  echo "--- wordclouds/loadings_"$fac"_wordcloud.png ---"

  if [ "$pole" == pos ] ; then
      grep '^[0-9]' $file | tr -s ' ' | sed 's/ /~/' | tr -dc '[:alpha:][:punct:][0-9]\n ' | tr  '[:space:]()' ' ' | tr '~' '\n' | tr -s ' ' | sed 's/^[ ]*//' | grep '[a-z]' | sed 's/ /_/' | cut -d' ' -f1,2 | sed 's/ / , /' | sed 's/, 0./, /' > wordclouds/wc.csv
   sed "s;FILENAME;wordclouds/loadings_"$fac"_wordcloud;" wordclouds/wcloud_template.py | sed -e 's/int(v)/float(v)/' -e 's/Oranges/Blues/' -e 's/orange/blue/' > p
  else
      grep '^[0-9]' $file | tr -s ' ' | sed 's/ /~/' | tr -dc '[:alpha:][:punct:][0-9]\n ' | tr  '[:space:]()' ' ' | tr '~' '\n' | tr -s ' ' | sed 's/^[ ]*//' | grep '[a-z]' | sed 's/ /_/' | cut -d' ' -f1,2 | sed 's/ / , /' | sed 's/, -0./, /' > wordclouds/wc.csv
    sed "s;FILENAME;wordclouds/loadings_"$fac"_wordcloud;" wordclouds/wcloud_template.py | sed 's/int(v)/float(v)/' > p
  fi

  python3 p

done < files 
rm -f x??

# keyword counts 

rm -f wordclouds/keywords*

while read i pole subcorpus
do
        echo "--- wordclouds/keywords_"f"$i""$pole""_wordcloud.png ---" 

        if [ "$subcorpus" == 'p' ] ; then
            subcorpus=pseudo
        else
            subcorpus=ref
        fi
                
        # factor loaded words
        rg "f"$i""$pole"" examples/factors | cut -d' ' -f2 | cut -d'_' -f2 > a   # word 1
        rg "f"$i""$pole"" examples/factors | cut -d' ' -f2 | cut -d'_' -f3 >> a  # word 2
        sort a | uniq > f
        
        # keeping only factor loaded words that are keywords
        cut -f2 keywords_"$subcorpus".txt > k
        cat f f k | sort | uniq -c | grep ' 3 ' | cut -c6- > fk
        
        column=$( echo " $i + 1 " | bc ) 
        cut -f1,"$column" sas/output_group5/group5_scores_only.tsv | tail +2 > ac
        
        # list texts scoring on this pole
        if [ "$pole" == pos ] ; then
            sort -nr -k2,2 ac | tr '\t' ' ' | grep -v -e '\-' -e ' 0$' | cut -d' ' -f1 > files
        else
            sort -nr -k2,2 ac | tr '\t' ' ' | grep -e '\-' | grep -v -e ' 0$' | cut -d' ' -f1 > files
        fi
        rg -f files text_index.txt | cut -d' ' -f2 | rg $subcorpus > fn
        
        # concatenate all the relevant files
        while read file
        do
            cat nodes/files/$file 
        done < fn > b
        
        # count the nodes
        cut -d'|' -f6 b | tr -d '.?!;,()"' | cut -d':' -f2 | sort | uniq -c | sed 's/^[ ]*//' | sort -t' ' -nr -k1,1 | grep -v '^$' | grep '[a-z]' | sort -t' ' -k2,2 | grep ' [a-z]' > c
                   
        # filter the nodes by factor keywords 
        join -1 1 -2 2 fk c | tr ' ' ',' > wordclouds/wc.csv
        
        if [ "$subcorpus" == ref ] ; then
        sed "s;FILENAME;wordclouds/keywords_"f"$i""$pole""_wordcloud;" wordclouds/wcloud_template.py | sed -e 's/int(v)/float(v)/' -e 's/Oranges/Greens/' -e 's/orange/green/' > p
        else
        sed "s;FILENAME;wordclouds/keywords_"f"$i""$pole""_wordcloud;" wordclouds/wcloud_template.py | sed -e 's/int(v)/float(v)/' -e 's/Oranges/Greys/' -e 's/orange/black/' > p
        fi
        
        python3 p
        
done < example_poles

}

comparelogdice () {

grep hydroxych no_repeats/pseudo* | grep -v ' 1 ' | cut -d' ' -f2- | cut -d' ' -f1,5 | sort -t' ' -k1,1 > p
grep hydroxych no_repeats/ref* | sort -t' ' -k4,4 -nr | cut -d' ' -f2,6 | sort -t' ' -k1,1 > s

join -a1 -1 1 -2 1 -o 1.1 -o 1.2 -o 2.2 -e 0 p s | sort -t' ' -k2,2 -nr | awk '{printf "%s %.2f %.2f\n", $1, $2, $3}' > ps
sort -t' ' -k2,2 -nr ps | sed 's/ 0.00/ 0/' | tr ' ' '&' | sed -e 's/$/ ~~/' | tr '~' '\' > pss

join -a1 -1 1 -2 1 -o 1.1 -o 1.2 -o 2.2 -e 0 s p | sort -t' ' -k2,2 -nr | awk '{printf "%s %.2f %.2f\n", $1, $2, $3}' > sc
sort -t' ' -k2,2 -nr sc | sed 's/ 0.00/ 0/' | tr ' ' '&' | sed -e 's/$/ ~~/' | tr '~' '\' > scs

#awk 'BEGIN{OFS="\t"} {if($2 > max[$1]){max[$1]=$2; line[$1]=$0}} END{for(c in line) print line[c]}' ps | awk '{printf "%s %.2f %.2f\n", $1, $2, $3}' | sort -t' ' -k2,2 -nr > psf

}

collocations () {
    
# fifty collocates with the highest log-dice
rg 'patients [a-z]' logdice/ref* | sort -t' ' -k6,6 -n | head -50 | cut -d' ' -f2 | sort | uniq > r
rg 'patients [a-z]' logdice/pseudo* | sort -t' ' -k6,6 -n | head -50 | cut -d' ' -f2 | sort | uniq > p

# real science only collocates
cat r r p | sort | uniq -c | grep ' 2 ' | cut -c6- > rc
# pseudo science only collocates
cat r r p | sort | uniq -c | grep ' 1 ' | cut -c6- > pc

word1=hydroxychloroquine
word2=treatment
#corpus=pseudo
corpus=ref
    
cut -d'|' -f2 nodes/casesensitive/$corpus* | sed 's/w1://' | sed 's/\.$/.~/' | tr '\n' ' ' | tr '~' '\n' | rg ""$word1" "$word2"|"$word1" [a-zA-Z]* "$word2"|"$word1" [a-zA-Z]* [a-zA-Z]* "$word2"|"$word1" [a-zA-Z]* [a-zA-Z]* [a-zA-Z]* "$word2"|"$word2" "$word1"|"$word2" [a-zA-Z] "$word1"|"$word2" [a-zA-Z] [a-zA-Z] "$word1"|"$word2" [a-zA-Z] [a-zA-Z] [a-zA-Z] "$word1" | sed 's/^[ ]*//" | sed 's/^/~item /' > c

sed -e "s/\($word1\) \($word2\)/\\\textbf{\1} \\\textbf{\2}/" \
    -e "s/\($word1\) \([a-zA-Z]*\) \($word2\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3}/" \
    -e "s/\($word1\) \([a-zA-Z]*\) \([a-zA-Z]*\) \($word2\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3} \\\textbf{\4}/" \
    -e "s/\($word1\) \([a-zA-Z]*\) \([a-zA-Z]*\) \([a-zA-Z]*\) \($word2\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3} \\\textbf{\4} \\\textbf{\5}/" \
    -e "s/\($word2\) \($word1\)/\\\textbf{\1} \\\textbf{\2}/" \
    -e "s/\($word2\) \([a-zA-Z]*\) \($word2\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3}/" \
    -e "s/\($word2\) \([a-zA-Z]*\) \([a-zA-Z]*\) \($word1\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3} \\\textbf{\4}/" \
    -e "s/\($word2\) \([a-zA-Z]*\) \([a-zA-Z]*\) \([a-zA-Z]*\) \($word1\)/\\\textbf{\1} \\\textbf{\2} \\\textbf{\3} \\\textbf{\4} \\\textbf{\5}/" c | tr '~' '\' > cf

}

wordcount () {

wc -l nodes/files/* | sed 's/^[ ]*//'
wc -l nodes/files/ref* | sed 's/^[ ]*//'

}

logdicesummary () {

# min logdice in sample    
cat no_repeats/pseudo* | rg 'p_' | sed -f collocates_stoplist.sed | sort | uniq -c | sort -nr | grep -E ' [2-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] ' | head -500 | sed 's/^[ ]*//' | cut -d' ' -f1,2,3,7 > p
sort -t' ' -k4,4 -n p | head -1 

cat no_repeats/ref* | rg 'p_' | sed -f collocates_stoplist.sed | sort | uniq -c | sort -nr | grep -E ' [2-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] ' | head -500 | sed 's/^[ ]*//' | cut -d' ' -f1,2,3,7  > r
sort -t' ' -k4,4 -n r | head -1 
    
# mean logdice
cat no_repeats/ref* | rg 'r_' | awk '{ sum += $NF } END { mean = sum / NR; print "Mean:", mean }' 
cat no_repeats/pseudo* | rg 'r_' | awk '{ sum += $NF } END { mean = sum / NR; print "Mean:", mean }' 

# quartiles
cat no_repeats/ref* | gawk '{arr[NR]=$NF} END{PROCINFO["sorted_in"]="@val_num_asc"; n=asort(arr, sorted); q1=sorted[int(n/4)]; q2=sorted[int(n/2)]; q3=sorted[int(n*3/4)]; print "Q1:", q1; print "Q2:", q2; print "Q3:", q3}' 
cat no_repeats/pseudo* | gawk '{arr[NR]=$NF} END{PROCINFO["sorted_in"]="@val_num_asc"; n=asort(arr, sorted); q1=sorted[int(n/4)]; q2=sorted[int(n/2)]; q3=sorted[int(n*3/4)]; print "Q1:", q1; print "Q2:", q2; print "Q3:", q3}' 

# median
cat no_repeats/ref* | gawk '{arr[NR] = $NF} END {n = asort(arr); if (n % 2 == 1) print arr[(n+1)/2]; else print (arr[n/2] + arr[(n/2)+1]) / 2}' 
cat no_repeats/pseudo* | gawk '{arr[NR] = $NF} END {n = asort(arr); if (n % 2 == 1) print arr[(n+1)/2]; else print (arr[n/2] + arr[(n/2)+1]) / 2}' 

# min
cat no_repeats/ref* | cut -d' ' -f1,2,6 | sort -n -t' ' -k3,3 | head -1 
cat no_repeats/pseudo* | cut -d' ' -f1,2,6 | sort -n -t' ' -k3,3 | head -1


}

#splitfiles 
#refcleanup
pseudocleanup
#kwcocunts
#keywords
#nodes
#wordfrequency
#collocates
#logdice
#selectfeatures
#sas
#datamatrix
#correlation
#formats
#factorlist
#examples
#wordclouds
#comparelogdice
#collocations
#logdicesummary



